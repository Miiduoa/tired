import SwiftUI
import FirebaseAuth

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var roomName: String = "聊天"
    @FocusState private var isInputFocused: Bool
    
    init(chatRoom: ChatRoom) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(chatRoom: chatRoom))
    }
    
    init(chatRoomId: String) {
        let temporaryRoom = ChatRoom(id: chatRoomId, type: .direct, participantIds: [], createdAt: Date(), updatedAt: Date())
        _viewModel = StateObject(wrappedValue: ChatViewModel(chatRoom: temporaryRoom))
    }

    var body: some View {
        VStack(spacing: 0) {
            conversationArea
        }
        .background(Color.appPrimaryBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.appPrimaryBackground.opacity(0.9), for: .navigationBar)
        .onAppear {
            _Concurrency.Task { await fetchRoomName() }
        }
    }
    
    private var conversationArea: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.exclamationmark.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("還沒有訊息")
                                .font(.headline)
                            Text("開始第一個訊息，展開對話吧。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 32)
                    } else {
                        ForEach(viewModel.messages) { uiMessage in
                            MessageView(uiMessage: uiMessage)
                                .id(uiMessage.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 80) // 讓最後一則不被輸入框遮住
            }
            .background(Color.appPrimaryBackground)
            .onChange(of: viewModel.messages) {
                scrollToBottom(scrollViewProxy)
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
    
    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 10) {
                TextField("輸入訊息...", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.appSecondaryBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                
                Button(action: { send() }) {
                    ZStack {
                        if viewModel.isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .white)
                                .padding(10)
                                .background(
                                    viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AnyShapeStyle(Color.gray.opacity(0.15))
                                    : AnyShapeStyle(AppDesignSystem.accentGradient)
                                )
                                .clipShape(Circle())
                        }
                    }
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }
    
    private func send() {
        viewModel.sendMessage()
        isInputFocused = false
    }
    
    private func fetchRoomName() async {
        let room = viewModel.chatRoom
        if let name = room.name, !name.isEmpty {
            self.roomName = name
            return
        }
        
        if room.type == .direct, let currentUserId = Auth.auth().currentUser?.uid {
            if let otherUserId = room.participantIds.first(where: { $0 != currentUserId }) {
                do {
                    if let otherUser = try await UserService.shared.fetchUserProfile(userId: otherUserId) {
                        self.roomName = otherUser.name
                    }
                } catch {
                    self.roomName = "聊天"
                }
            }
        } else {
            self.roomName = room.name ?? "群組聊天"
        }
    }
}

struct MessageView: View {
    let uiMessage: UIMessage
    private var isCurrentUser: Bool {
        uiMessage.message.senderId == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isCurrentUser {
                Spacer(minLength: 40)
                bubble(text: uiMessage.message.text, isCurrentUser: true)
            } else {
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(uiMessage.sender?.name ?? "使用者")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    bubble(text: uiMessage.message.text, isCurrentUser: false)
                }
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var avatar: some View {
        AsyncImage(url: URL(string: uiMessage.sender?.avatarUrl ?? "")) { image in
            image.resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundColor(.gray.opacity(0.45))
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
    
    private func bubble(text: String, isCurrentUser: Bool) -> some View {
        Text(text)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(isCurrentUser ? .white : .primary)
            .background(
                Group {
                    if isCurrentUser {
                        AppDesignSystem.accentGradient
                    } else {
                        Color.appSecondaryBackground
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrentUser ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: 280, alignment: isCurrentUser ? .trailing : .leading)
    }
}
