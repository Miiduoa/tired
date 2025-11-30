import Foundation
import Combine
import FirebaseAuth

class ChatListViewModel: ObservableObject {
    @Published var chatRooms = [ChatRoom]()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let chatService = ChatService.shared
    private let userService = UserService.shared

    init() {
        fetchChatRooms()
    }

    deinit {
        chatService.stopObservingChatRooms()
    }

    func fetchChatRooms(forceRestart: Bool = false) {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Silently fail or clear rooms if not logged in, instead of showing error
            chatRooms = []
            isLoading = false
            return
        }

        if forceRestart {
            chatService.stopObservingChatRooms()
        }

        isLoading = true
        chatService.observeChatRooms(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let rooms):
                    self?.chatRooms = rooms
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch chat rooms: \(error.localizedDescription)"
                }
            }
        }
    }

    func refresh() {
        fetchChatRooms(forceRestart: true)
    }

    func startDirectChat(withEmail email: String) async throws -> (roomId: String, otherUser: UserProfile) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ChatListViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "尚未登入，請先登入後再開始聊天。"])
        }

        guard let otherUser = try await userService.fetchUserProfile(byEmail: email.lowercased()) else {
            throw NSError(domain: "ChatListViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到此 Email 的使用者，請確認輸入正確。"])
        }

        guard let otherUserId = otherUser.id else {
            throw NSError(domain: "ChatListViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "無法取得對方的使用者 ID。"])
        }

        guard otherUserId != currentUserId else {
            throw NSError(domain: "ChatListViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "無法與自己開啟私訊，請輸入其他使用者的 Email。"])
        }

        let roomId = try await chatService.getOrCreateDirectChatRoom(with: otherUserId)
        return (roomId, otherUser)
    }
}
