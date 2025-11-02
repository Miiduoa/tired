import Foundation
import FirebaseFirestore

protocol ChatServiceProtocol {
    func conversations(for userId: String) async -> [Conversation]
    func messages(in conversationId: String, limit: Int) async -> [Message]
    func send(conversationId: String, from userId: String, name: String, text: String) async throws -> Message
    func createConversation(participantIds: [String], title: String) async throws -> Conversation
    func markRead(conversationId: String, userId: String) async
    func unreadCount(conversationId: String, userId: String, sampleLimit: Int) async -> Int
    func sendAttachment(conversationId: String, from userId: String, name: String, attachmentURLs: [String]) async throws -> Message
    func conversation(id: String, for userId: String) async -> Conversation?
}

@MainActor
final class ChatService: ChatServiceProtocol {
    static let shared = ChatService()
    private let db = Firestore.firestore()
    
    // 使用本地快取作為後備
    private var conversationsCache: [String: [Conversation]] = [:]
    private var messagesCache: [String: [Message]] = [:]
    private var listeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    func conversations(for userId: String) async -> [Conversation] {
        do {
            // 從 Firestore 獲取對話列表
            let snapshot = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            
            let conversations = snapshot.documents.compactMap { doc -> Conversation? in
                guard let data = try? doc.data(as: Conversation.self) else { return nil }
                return data
            }
            
            // 更新快取
            conversationsCache[userId] = conversations
            
            // 如果 Firestore 沒有數據，返回 demo 數據
            if conversations.isEmpty {
                return await createDemoConversation(for: userId)
            }
            
            return conversations
        } catch {
            print("❌ 獲取對話列表失敗: \(error.localizedDescription)")
            // 返回快取或 demo 數據
            if let cached = conversationsCache[userId], !cached.isEmpty {
                return cached
            }
            return await createDemoConversation(for: userId)
        }
    }
    
    private func createDemoConversation(for userId: String) async -> [Conversation] {
        let convo = Conversation(
            id: "c_demo",
            title: "產品小組",
            participantIds: [userId, "u_alex", "u_mia"],
            lastMessagePreview: "歡迎加入！我們下週開會。",
            updatedAt: Date().addingTimeInterval(-120)
        )
        conversationsCache[userId] = [convo]
        messagesCache[convo.id] = [
            Message(id: "m1", conversationId: convo.id, senderId: "u_alex", senderName: "Alex", text: "歡迎加入！", createdAt: Date().addingTimeInterval(-600), attachments: []),
            Message(id: "m2", conversationId: convo.id, senderId: userId, senderName: "你", text: "大家好～", createdAt: Date().addingTimeInterval(-300), attachments: [])
        ]
        return [convo]
    }

    func messages(in conversationId: String, limit: Int) async -> [Message] {
        do {
            // 從 Firestore 獲取訊息
            let snapshot = try await db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "createdAt", descending: false)
                .limit(to: limit)
                .getDocuments()
            
            let messages = snapshot.documents.compactMap { doc -> Message? in
                guard let data = try? doc.data(as: Message.self) else { return nil }
                return data
            }
            
            // 更新快取
            messagesCache[conversationId] = messages
            
            // 如果 Firestore 沒有數據，返回快取
            if messages.isEmpty, let cached = messagesCache[conversationId] {
                return cached
            }
            
            return messages
        } catch {
            print("❌ 獲取訊息失敗: \(error.localizedDescription)")
            // 返回快取
            return messagesCache[conversationId] ?? []
        }
    }

    func send(conversationId: String, from userId: String, name: String, text: String) async throws -> Message {
        let msg = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: userId,
            senderName: name,
            text: text,
            createdAt: Date(),
            attachments: []
        )
        
        do {
            // 保存到 Firestore
            try db.collection("messages").document(msg.id).setData(from: msg)
            
            // 更新對話的最後訊息
            try await db.collection("conversations").document(conversationId).updateData([
                "lastMessagePreview": text,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 更新快取
            var cached = messagesCache[conversationId] ?? []
            cached.append(msg)
            messagesCache[conversationId] = cached
            
            return msg
        } catch {
            print("❌ 發送訊息失敗: \(error.localizedDescription)")
            // 即使失敗也加入快取，讓 UI 顯示
            var cached = messagesCache[conversationId] ?? []
            cached.append(msg)
            messagesCache[conversationId] = cached
            throw error
        }
    }

    func createConversation(participantIds: [String], title: String) async throws -> Conversation {
        let convo = Conversation(
            id: UUID().uuidString,
            title: title,
            participantIds: participantIds,
            lastMessagePreview: "",
            updatedAt: Date()
        )
        
        do {
            // 保存到 Firestore
            try db.collection("conversations").document(convo.id).setData(from: convo)
            
            // 更新快取
            for uid in participantIds {
                var cached = conversationsCache[uid] ?? []
                cached.append(convo)
                conversationsCache[uid] = cached
            }
            
            messagesCache[convo.id] = []
            
            return convo
        } catch {
            print("❌ 創建對話失敗: \(error.localizedDescription)")
            throw error
        }
    }

    func markRead(conversationId: String, userId: String) async {
        ReadStateStore.shared.markAsOpened(conversationId: conversationId)
    }

    func unreadCount(conversationId: String, userId: String, sampleLimit: Int) async -> Int {
        let last = ReadStateStore.shared.lastOpened(conversationId: conversationId) ?? .distantPast
        let allMessages = await messages(in: conversationId, limit: sampleLimit)
        let unread = allMessages.filter { $0.createdAt > last && $0.senderId != userId }
        return unread.count
    }

    func sendAttachment(conversationId: String, from userId: String, name: String, attachmentURLs: [String]) async throws -> Message {
        let msg = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: userId,
            senderName: name,
            text: "",
            createdAt: Date(),
            attachments: attachmentURLs
        )
        
        do {
            // 保存到 Firestore
            try db.collection("messages").document(msg.id).setData(from: msg)
            
            // 更新對話的最後訊息
            try await db.collection("conversations").document(conversationId).updateData([
                "lastMessagePreview": "[附件]",
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 更新快取
            var cached = messagesCache[conversationId] ?? []
            cached.append(msg)
            messagesCache[conversationId] = cached
            
            return msg
        } catch {
            print("❌ 發送附件失敗: \(error.localizedDescription)")
            throw error
        }
    }

    func conversation(id: String, for userId: String) async -> Conversation? {
        let conversations = await conversations(for: userId)
        return conversations.first(where: { $0.id == id })
    }
    
    // MARK: - Realtime Listeners
    
    func listenToMessages(conversationId: String, onChange: @escaping ([Message]) -> Void) {
        // 移除舊的 listener
        listeners["messages_\(conversationId)"]?.remove()
        
        // 創建新的 listener
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    print("❌ 監聽訊息失敗: \(error?.localizedDescription ?? "未知錯誤")")
                    return
                }
                
                let messages = snapshot.documents.compactMap { doc -> Message? in
                    try? doc.data(as: Message.self)
                }
                
                // 更新快取
                self?.messagesCache[conversationId] = messages
                
                // 通知更新
                onChange(messages)
            }
        
        listeners["messages_\(conversationId)"] = listener
    }
    
    func stopListening(conversationId: String) {
        listeners["messages_\(conversationId)"]?.remove()
        listeners.removeValue(forKey: "messages_\(conversationId)")
    }
    
    deinit {
        // 清理所有 listeners
        listeners.values.forEach { $0.remove() }
    }
}
