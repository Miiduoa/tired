import SwiftUI
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showingNewChatSheet = false
    @State private var pendingChatRoomId: String?
    @State private var isChatNavigationActive = false
    @State private var newChatEmail: String = ""
    @State private var creationError: String?
    @State private var isCreatingChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack {
                    if let errorMessage = viewModel.errorMessage {
                        errorState(errorMessage)
                    } else if viewModel.isLoading && viewModel.chatRooms.isEmpty {
                        ProgressView("載入聊天中...")
                            .padding(.top, 32)
                    } else if viewModel.chatRooms.isEmpty {
                        emptyState
                    } else {
                        List(viewModel.chatRooms) { room in
                            NavigationLink(destination: ChatView(chatRoom: room)) {
                                ChatRoomRow(room: room)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            viewModel.refresh()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("訊息")
            .navigationDestination(isPresented: $isChatNavigationActive) {
                if let roomId = pendingChatRoomId {
                    ChatView(chatRoomId: roomId)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        creationError = nil
                        newChatEmail = ""
                        showingNewChatSheet = true
                    } label: {
                        Label("新聊天", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewChatSheet) {
                NewChatSheet(
                    email: $newChatEmail,
                    errorMessage: $creationError,
                    isLoading: $isCreatingChat,
                    onSubmit: { email in
                        await createChat(with: email)
                    }
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                viewModel.fetchChatRooms(forceRestart: true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("目前沒有對話")
                .font(.headline)
            Text("開始一個新的聊天，或等待組織通知。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showingNewChatSheet = true
            } label: {
                Label("開啟新聊天", systemImage: "plus.bubble")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 48)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            Button("重新載入") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 48)
    }

    private func createChat(with email: String) async {
        guard !isCreatingChat else { return }
        isCreatingChat = true
        creationError = nil

        do {
            let result = try await viewModel.startDirectChat(withEmail: email)
            await MainActor.run {
                pendingChatRoomId = result.roomId
                isChatNavigationActive = true
                showingNewChatSheet = false
                ToastManager.shared.showToast(message: "已開啟與 \(result.otherUser.name) 的對話", type: .success)
            }
        } catch {
            await MainActor.run {
                creationError = error.localizedDescription
                ToastManager.shared.showToast(message: error.localizedDescription, type: .error)
            }
        }

        await MainActor.run {
            isCreatingChat = false
        }
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    
    @State private var roomName: String = "載入中..."
    @State private var roomAvatarUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: roomAvatarUrl ?? "")) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                Image(systemName: room.type == .direct ? "person.circle.fill" : "person.3.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(roomName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(room.lastMessage?.text ?? "尚無訊息")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let lastTimestamp = room.lastMessage?.timestamp {
                Text(lastTimestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text(room.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            _Concurrency.Task {
                await fetchRoomDetails()
            }
        }
    }
    
    private func fetchRoomDetails() async {
        if let name = room.name, !name.isEmpty {
            self.roomName = name
            self.roomAvatarUrl = room.avatarUrl
            return
        }
        
        if room.type == .direct, let currentUserId = Auth.auth().currentUser?.uid {
            if let otherUserId = room.participantIds.first(where: { $0 != currentUserId }) {
                do {
                    if let otherUser = try await UserService.shared.fetchUserProfile(userId: otherUserId) {
                        self.roomName = otherUser.name
                        self.roomAvatarUrl = otherUser.avatarUrl
                    }
                } catch {
                    self.roomName = "聊天"
                }
            }
        } else {
            self.roomName = room.name ?? "群組聊天"
            self.roomAvatarUrl = room.avatarUrl
        }
    }
}

private struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @Binding var errorMessage: String?
    @Binding var isLoading: Bool
    let onSubmit: (String) async -> Void

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("輸入對方 Email") {
                    TextField("example@domain.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            _Concurrency.Task { await submit() }
                        }
                }

                if let errorMessage = errorMessage {
                    SwiftUI.Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                    }
                }

                SwiftUI.Section {
                    Label("目前只支援透過 Email 發起一對一聊天。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("新聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        _Concurrency.Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("開始")
                        }
                    }
                    .disabled(!isEmailValid || isLoading)
                }
            }
        }
    }

    private func submit() async {
        guard isEmailValid, !isLoading else { return }
        await onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
