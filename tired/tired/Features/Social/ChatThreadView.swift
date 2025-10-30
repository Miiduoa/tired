import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

struct ChatThreadView: View {
    let session: AppSession
    let conversation: Conversation
    let chatService: ChatServiceProtocol

    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var token: CancelableToken?
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var alertMessage: String? = nil
    @State private var previewURL: URL? = nil
    @State private var shareURL: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { m in
                            ChatBubble(
                                message: m,
                                isMe: m.senderId == session.user.id,
                                onPreview: { url in
                                    previewURL = url
                                },
                                onShare: { url in
                                    shareURL = url
                                }
                            )
                            .id(m.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages) { _, _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            inputBar
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await attachRealtimeOrLoad()
            ReadStateStore.shared.markOpened(conversationId: conversation.id)
        }
        .onDisappear { token?.cancel(); token = nil }
        .alert("上傳限制", isPresented: Binding(get: { alertMessage != nil }, set: { newValue in
            if !newValue { alertMessage = nil }
        })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(item: Binding(get: { previewURL.map { PreviewItem(url: $0) } }, set: { _ in previewURL = nil })) { item in
            NavigationStack { DocumentPreviewView(url: item.url) }
        }
        .sheet(item: Binding(get: { shareURL.map { PreviewItem(url: $0) } }, set: { _ in shareURL = nil })) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .any(of: [.images, .videos])) {
                Image(systemName: "paperclip.circle.fill").font(.title3)
            }
            .onChange(of: $selectedItems.wrappedValue) { _, items in
                Task { await handlePicked(items: items) }
            }
            TextField("輸入訊息…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func load() async {
        isLoading = true
        messages = await chatService.messages(in: conversation.id, limit: 100)
        await chatService.markRead(conversationId: conversation.id, userId: session.user.id)
        isLoading = false
    }

    @MainActor
    private func attachRealtimeOrLoad() async {
        if let realtime = chatService as? ChatRealtimeListening {
            token = realtime.listenMessages(in: conversation.id, limit: 100) { items in
                self.messages = items
                ReadStateStore.shared.markOpened(conversationId: conversation.id)
                Task { await chatService.markRead(conversationId: conversation.id, userId: session.user.id) }
            }
        } else {
            await load()
        }
    }

    @MainActor
    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let name = session.user.displayName.isEmpty ? (session.user.email.isEmpty ? "你" : session.user.email) : session.user.displayName
        _ = try? await chatService.send(conversationId: conversation.id, from: session.user.id, name: name, text: text)
        await load()
    }

    @MainActor
    private func handlePicked(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var urls: [String] = []
        uploadingTotal = min(items.count, 3)
        uploadingDone = 0
        for item in items.prefix(3) {
            // If it's an image, load Data then create UIImage for resize
            if let ct = item.supportedContentTypes.first, ct.conforms(to: .image),
               let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let maxDim = AppConfig.maxImageMaxDimension
                let maxBytes = AppConfig.maxUploadImageBytes
                let data = MediaUtils.resizedImageData(img, maxDimension: maxDim, maxBytes: maxBytes) ?? img.jpegData(compressionQuality: 0.8)
                guard let finalData = data, finalData.count <= maxBytes else {
                    alertMessage = "圖片過大，已超過限制 (\(maxBytes/1_000_000)MB)。"
                    continue
                }
                if let url = try? await UploadAPI.uploadWithProgress(data: finalData, mime: "image/jpeg", progress: { _ in }) { urls.append(url.absoluteString) }
                uploadingDone += 1
                continue
            }
            // Fallback: load raw Data (videos or other files)
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Determine mime from contentType if possible
                let mime: String
                if let ct = item.supportedContentTypes.first {
                    if ct.conforms(to: .mpeg4Movie) || ct == .movie { mime = "video/mp4" }
                    else if ct.conforms(to: .png) { mime = "image/png" }
                    else if ct.conforms(to: .jpeg) { mime = "image/jpeg" }
                    else { mime = "application/octet-stream" }
                } else {
                    mime = "application/octet-stream"
                }
                // Size checks
                if mime.hasPrefix("video/") {
                    if data.count > AppConfig.maxUploadVideoBytes {
                        alertMessage = "影片過大，已超過限制 (\(AppConfig.maxUploadVideoBytes/1_000_000)MB)。"
                        continue
                    }
                } else if mime.hasPrefix("image/") {
                    if data.count > AppConfig.maxUploadImageBytes {
                        alertMessage = "圖片過大，已超過限制 (\(AppConfig.maxUploadImageBytes/1_000_000)MB)。"
                        continue
                    }
                }
                if let url = try? await UploadAPI.uploadWithProgress(data: data, mime: mime, progress: { _ in }) { urls.append(url.absoluteString) }
                uploadingDone += 1
            }
        }
        guard !urls.isEmpty else { return }
        let name = session.user.displayName.isEmpty ? (session.user.email.isEmpty ? "你" : session.user.email) : session.user.displayName
        _ = try? await chatService.sendAttachment(conversationId: conversation.id, from: session.user.id, name: name, attachmentURLs: urls)
        selectedItems.removeAll()
        await load()
        uploadingTotal = 0
        uploadingDone = 0
    }
}

private struct ChatBubble: View {
    let message: Message
    let isMe: Bool
    let onPreview: (URL) -> Void
    let onShare: (URL) -> Void

    var body: some View {
        HStack {
            if isMe { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                if !isMe {
                    Text(message.senderName).font(.caption).foregroundStyle(.secondary)
                }
                if let atts = message.attachments, !atts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(atts, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AttachmentView(url: url, onTap: { tapped in
                                    onPreview(tapped)
                                }, onShare: { tapped in
                                    onShare(tapped)
                                })
                            }
                        }
                        if !message.text.isEmpty {
                            Text(message.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(8)
                    .background(isMe ? Color.blue.opacity(0.85) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(isMe ? .white : .primary)
                } else {
                    Text(message.text)
                        .padding(10)
                        .background(isMe ? Color.blue.opacity(0.85) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(isMe ? .white : .primary)
                }
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMe { Spacer() }
        }
    }
}

private struct AttachmentView: View {
    let url: URL
    let onTap: (URL) -> Void
    let onShare: (URL) -> Void
    @State private var image: UIImage? = nil
    @State private var isVideo: Bool = false

    var body: some View {
        Group {
            if let image {
                ZStack(alignment: .center) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipped()
                        .cornerRadius(8)
                    if isVideo {
                        Image(systemName: "play.circle.fill").font(.system(size: 40)).foregroundStyle(.white)
                    }
                }
                .onTapGesture { onTap(url) }
                .contextMenu {
                    Button { onShare(url) } label: { Label("分享", systemImage: "square.and.arrow.up") }
                    Button { onTap(url) } label: { Label("預覽", systemImage: "doc.viewfinder") }
                }
            } else if isLikelyImage(url) == false {
                // Generic tile for non-image (e.g., file)
                Button { onTap(url) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isLikelyVideo(url) ? "play.rectangle.fill" : "doc.fill").foregroundStyle(.white)
                        Text(isLikelyVideo(url) ? "影片" : "附件")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 140, height: 80)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                }
                .contextMenu {
                    Button { onShare(url) } label: { Label("分享", systemImage: "square.and.arrow.up") }
                    Button { onTap(url) } label: { Label("預覽", systemImage: "doc.viewfinder") }
                }
            } else {
                Rectangle().fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 80)
                    .overlay { ProgressView() }
            }
        }
        .task(id: url) {
            if isLikelyVideo(url) {
                isVideo = true
                if let thumb = await VideoThumbnailCache.shared.thumbnail(for: url) { image = thumb }
            } else if isLikelyImage(url) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) { image = img }
                } catch { }
            }
        }
    }

    private func isLikelyImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext) || url.absoluteString.hasPrefix("data:image")
    }

    private func isLikelyVideo(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v"].contains(ext) || url.absoluteString.contains("video=")
    }

}

private struct PreviewItem: Identifiable {
    let url: URL
    var id: URL { url }
}
