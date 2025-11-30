import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class ChatViewModel: ObservableObject {
    @Published var messages = [UIMessage]()
    @Published var errorMessage: String?
    @Published var messageText: String = ""
    @Published var isSending: Bool = false
    
    let chatRoom: ChatRoom
    private var cancellables = Set<AnyCancellable>()
    private var messageListener: ListenerRegistration?
    
    private var userProfileCache = [String: UserProfile]()

    init(chatRoom: ChatRoom) {
        self.chatRoom = chatRoom
        fetchParticipantProfiles()
        observeMessages()
    }
    
    private func fetchParticipantProfiles() {
        let participantIds = chatRoom.participantIds
        let userService = UserService.shared
        
        _Concurrency.Task {
            await withTaskGroup(of: UserProfile?.self) { group in
                for userId in participantIds {
                    group.addTask {
                        do {
                            return try await userService.fetchUserProfile(userId: userId)
                        } catch {
                            return nil
                        }
                    }
                }
                
                var fetchedProfiles: [UserProfile] = []
                for await profile in group {
                    if let profile {
                        fetchedProfiles.append(profile)
                    }
                }
                
                await MainActor.run {
                    for profile in fetchedProfiles {
                        if let id = profile.id {
                            self.userProfileCache[id] = profile
                        }
                    }
                    // 重新載入訊息以附加使用者資料
                    self.observeMessages()
                }
            }
        }
    }

    func observeMessages() {
        guard let roomId = chatRoom.id else {
            errorMessage = "Invalid chat room ID."
            return
        }
        
        messageListener?.remove()
        messageListener = ChatService.shared.observeMessages(inRoomId: roomId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let messages):
                    self.messages = messages.map { message in
                        let senderProfile = self.userProfileCache[message.senderId]
                        return UIMessage(message: message, sender: senderProfile)
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sendMessage() {
        // fire-and-forget replaced by async flow to provide loading & error feedback
        _Concurrency.Task { await sendMessageAsync() }
    }

    @MainActor
    func sendMessageAsync() async {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let roomId = chatRoom.id else {
            errorMessage = "Invalid chat room ID."
            return
        }

        guard let senderId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in."
            return
        }

        // prevent double-send
        if isSending { return }
        isSending = true

        let textToSend = trimmed
        // clear input for instant UI feedback
        self.messageText = ""

        do {
            try await ChatService.shared.sendMessageAsync(textToSend, inRoomId: roomId, senderId: senderId)
            // success: leave messageText cleared
            isSending = false
        } catch {
            // restore text so user can retry
            self.errorMessage = "Failed to send message: \(error.localizedDescription)"
            self.messageText = textToSend
            isSending = false
        }
    }
    
    deinit {
        messageListener?.remove()
    }
}
