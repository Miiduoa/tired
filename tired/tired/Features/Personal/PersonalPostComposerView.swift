import SwiftUI

struct PersonalPostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summary: String = ""
    @State private var content: String = ""
    @State private var category: PostCategory = .general
    @State private var visibility: PostVisibility = .public
    @State private var attachmentDraft: String = ""
    @State private var attachments: [AttachmentItem] = []
    @State private var summaryError: String?
    @State private var contentError: String?
    @State private var attachmentError: String?
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @FocusState private var focusedField: Field?
    let onSubmit: (String, String, PostCategory, PostVisibility, [URL]) async throws -> Void
    
    private enum Field: Hashable {
        case summary
        case content
        case attachment
    }
    
    private struct AttachmentItem: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        
        var displayName: String {
            if let host = url.host {
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return path.isEmpty ? host : "\(host)/\(path)"
            }
            return url.absoluteString
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("一句話描述重點", text: $summary)
                        .focused($focusedField, equals: .summary)
                        .onChange(of: summary) { newValue in
                            summary = String(newValue.prefix(80))
                            if summaryError != nil { summaryError = nil }
                        }
                } header: {
                    Text("重點摘要")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.count)/80 字")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let summaryError {
                            Text(summaryError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                        .focused($focusedField, equals: .content)
                        .onChange(of: content) { _ in
                            if contentError != nil { contentError = nil }
                        }
                } header: {
                    Text("內容")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("至少 10 個字，詳細描述讓更多人理解你的內容。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let contentError {
                            Text(contentError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Section {
                    Picker("類別", selection: $category) {
                        ForEach(PostCategory.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                } header: {
                    Text("分類")
                }
                Section {
                    Picker("曝光範圍", selection: $visibility) {
                        ForEach(PostVisibility.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                } header: {
                    Text("可見度")
                }
                Section {
                    if attachments.isEmpty {
                        Text("可選填，提供作品集、社群或活動報名連結。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
                            HStack {
                                Label(attachment.displayName, systemImage: "paperclip")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(role: .destructive) {
                                    removeAttachment(attachment)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    TextField("貼上網址", text: $attachmentDraft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .attachment)
                        .onChange(of: attachmentDraft) { _ in
                            if attachmentError != nil { attachmentError = nil }
                        }
                    Button {
                        addAttachment()
                    } label: {
                        Label("新增附件", systemImage: "paperclip.badge.plus")
                    }
                    .disabled(attachmentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("附件")
                } footer: {
                    if let attachmentError {
                        Text(attachmentError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("發佈貼文")
            .alert("發佈失敗", isPresented: Binding<Bool>(get: { submissionError != nil }, set: { isPresented in
                if !isPresented { submissionError = nil }
            })) {
                Button("知道了", role: .cancel) { submissionError = nil }
            } message: {
                Text(submissionError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("發佈") {
                            Task { await submit() }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }
    
    private var trimmedSummary: String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSubmit: Bool {
        !isSubmitting && !trimmedSummary.isEmpty && !trimmedContent.isEmpty
    }
    
    @MainActor
    private func submit() async {
        guard validate() else { return }
        isSubmitting = true
        do {
            try await onSubmit(trimmedSummary, trimmedContent, category, visibility, attachments.map { $0.url })
            isSubmitting = false
            dismiss()
        } catch {
            isSubmitting = false
            submissionError = error.localizedDescription
        }
    }
    
    private func validate() -> Bool {
        summaryError = trimmedSummary.count >= 4 ? nil : "摘要至少需要 4 個字元" 
        contentError = trimmedContent.count >= 10 ? nil : "內容至少需要 10 個字元"
        return summaryError == nil && contentError == nil
    }
    
    private func addAttachment() {
        let trimmed = attachmentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            attachmentError = "請輸入附件網址"
            return
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            attachmentError = "請輸入有效的網址"
            return
        }
        if attachments.contains(where: { $0.url == url }) {
            attachmentError = "附件已存在"
            return
        }
        attachments.append(AttachmentItem(url: url))
        attachmentDraft = ""
        attachmentError = nil
    }
    
    private func removeAttachment(_ attachment: AttachmentItem) {
        attachments.removeAll { $0 == attachment }
    }
}
