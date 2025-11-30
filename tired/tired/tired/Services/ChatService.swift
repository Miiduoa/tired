import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 聊天室與訊息管理服務
class ChatService {

    static let shared = ChatService()
    private let db = Firestore.firestore()

    private var chatRoomsListener: ListenerRegistration?

    private init() {}

    private var chatRoomsCollection: CollectionReference {
        return db.collection("chatRooms")
    }

    private func messagesCollection(for roomId: String) -> CollectionReference {
        return chatRoomsCollection.document(roomId).collection("messages")
    }

    // MARK: - Chat Room Management

    func observeChatRooms(for userId: String, completion: @escaping (Result<[ChatRoom], Error>) -> Void) {
        chatRoomsListener?.remove()

        chatRoomsListener = chatRoomsCollection
            .whereField("participantIds", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let chatRooms = documents.compactMap { doc -> ChatRoom? in
                    try? doc.data(as: ChatRoom.self)
                }
                completion(.success(chatRooms))
            }
    }
    
    func stopObservingChatRooms() {
        chatRoomsListener?.remove()
        chatRoomsListener = nil
    }
    
    func getOrCreateDirectChatRoom(with otherUserId: String) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let participantIds = [currentUserId, otherUserId].sorted()
        let roomId = participantIds.joined(separator: "_")

        let roomRef = chatRoomsCollection.document(roomId)
        
        let document = try await roomRef.getDocument()
        
        if document.exists {
            return roomId
        } else {
            let newRoom = ChatRoom(
                id: roomId,
                type: .direct,
                participantIds: participantIds,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try roomRef.setData(from: newRoom)
            return roomId
        }
    }

    func getOrCreateOrganizationChatRoom(for organization: Organization) async throws -> String {
        guard let orgId = organization.id else {
            throw NSError(domain: "ChatServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Organization ID is missing."])
        }

        let roomRef = chatRoomsCollection.document(orgId)
        
        let document = try await roomRef.getDocument()

        if document.exists {
            return orgId
        } else {
            let orgService = OrganizationService()
            let memberships = try await orgService.fetchOrganizationMembers(organizationId: orgId)
            let participantIds = memberships.map { $0.userId }
            
            let newRoom = ChatRoom(
                id: orgId,
                type: .organization,
                participantIds: participantIds,
                organizationId: orgId,
                name: organization.name,
                avatarUrl: organization.avatarUrl,
                createdAt: Date(),
                updatedAt: Date()
            )

            try roomRef.setData(from: newRoom)
            return orgId
        }
    }

    func addUserToOrganizationChatRoom(userId: String, organizationId: String) async throws {
        let roomRef = chatRoomsCollection.document(organizationId)
        try await roomRef.updateData([
            "participantIds": FieldValue.arrayUnion([userId])
        ])
    }

    func removeUserFromOrganizationChatRoom(userId: String, organizationId: String) async throws {
        let roomRef = chatRoomsCollection.document(organizationId)
        try await roomRef.updateData([
            "participantIds": FieldValue.arrayRemove([userId])
        ])
    }

    // MARK: - Message Management

    func sendMessage(_ messageText: String, inRoomId roomId: String, senderId: String, completion: @escaping (Error?) -> Void) {
        let message = ChatMessage(
            roomId: roomId,
            senderId: senderId,
            text: messageText,
            timestamp: Date()
        )
        
        do {
            let newDocRef = try messagesCollection(for: roomId).addDocument(from: message)
            
            let lastMessageInfo = LastMessageInfo(
                messageId: newDocRef.documentID,
                text: message.text,
                senderId: message.senderId,
                timestamp: message.timestamp
            )
            
            let updateData: [String: Any] = [
                "lastMessage": try Firestore.Encoder().encode(lastMessageInfo),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            chatRoomsCollection.document(roomId).updateData(updateData) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }

    // Async/await wrapper for sendMessage
    func sendMessageAsync(_ messageText: String, inRoomId roomId: String, senderId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.sendMessage(messageText, inRoomId: roomId, senderId: senderId) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func observeMessages(inRoomId roomId: String, completion: @escaping (Result<[ChatMessage], Error>) -> Void) -> ListenerRegistration {
        return messagesCollection(for: roomId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let messages = documents.compactMap { doc -> ChatMessage? in
                    try? doc.data(as: ChatMessage.self)
                }
                completion(.success(messages))
            }
    }
    
    deinit {
        chatRoomsListener?.remove()
    }
}
