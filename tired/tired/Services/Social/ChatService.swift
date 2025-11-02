import Foundation

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

final class ChatService: ChatServiceProtocol {
    static let shared = ChatService()
    private init() {}

    private var conversationsStore: [String: [Conversation]] = [:] // userId -> conversations
    private var messagesStore: [String: [Message]] = [:] // conversationId -> messages

    func conversations(for userId: String) async -> [Conversation] {
        if let cached = conversationsStore[userId] { return cached.sorted { $0.updatedAt > $1.updatedAt } }
        // Seed demo data
        let convo = Conversation(
            id: "c_demo",
            title: "產品小組",
            participantIds: [userId, "u_alex", "u_mia"],
            lastMessagePreview: "歡迎加入！我們下週開會。",
            updatedAt: Date().addingTimeInterval(-120)
        )
        conversationsStore[userId] = [convo]
        messagesStore[convo.id] = [
            Message(id: "m1", conversationId: convo.id, senderId: "u_alex", senderName: "Alex", text: "歡迎加入！", createdAt: Date().addingTimeInterval(-600), attachments: []),
            Message(id: "m2", conversationId: convo.id, senderId: userId, senderName: "你", text: "大家好～", createdAt: Date().addingTimeInterval(-300), attachments: [])
        ]
        return conversationsStore[userId] ?? []
    }

    func messages(in conversationId: String, limit: Int) async -> [Message] {
        let all = messagesStore[conversationId] ?? []
        return Array(all.sorted { $0.createdAt > $1.createdAt }.prefix(limit)).sorted { $0.createdAt < $1.createdAt }
    }

    func send(conversationId: String, from userId: String, name: String, text: String) async throws -> Message {
        let msg = Message(id: UUID().uuidString, conversationId: conversationId, senderId: userId, senderName: name, text: text, createdAt: Date(), attachments: [])
        var list = messagesStore[conversationId] ?? []
        list.append(msg)
        messagesStore[conversationId] = list
        // Update conversation preview
        for (uid, var convos) in conversationsStore {
            if let idx = convos.firstIndex(where: { $0.id == conversationId }) {
                let old = convos[idx]
                convos[idx] = Conversation(id: old.id, title: old.title, participantIds: old.participantIds, lastMessagePreview: text, updatedAt: Date())
                conversationsStore[uid] = convos
            }
        }
        return msg
    }

    func createConversation(participantIds: [String], title: String) async throws -> Conversation {
        let convo = Conversation(id: UUID().uuidString, title: title, participantIds: participantIds, lastMessagePreview: "", updatedAt: Date())
        for uid in participantIds {
            var list = conversationsStore[uid] ?? []
            list.append(convo)
            conversationsStore[uid] = list
        }
        messagesStore[convo.id] = []
        return convo
    }

    func markRead(conversationId: String, userId: String) async {
        // Demo store: no-op; UI 層已有本地 ReadStateStore
    }

    func unreadCount(conversationId: String, userId: String, sampleLimit: Int) async -> Int {
        // Demo: 以本地 ReadStateStore 計算最近訊息是否未讀
        let last = ReadStateStore.shared.lastOpened(conversationId: conversationId) ?? .distantPast
        let recent = (messagesStore[conversationId] ?? []).filter { $0.createdAt > last }
        return recent.count
    }

    func sendAttachment(conversationId: String, from userId: String, name: String, attachmentURLs: [String]) async throws -> Message {
        let msg = Message(id: UUID().uuidString, conversationId: conversationId, senderId: userId, senderName: name, text: "", createdAt: Date(), attachments: attachmentURLs)
        var list = messagesStore[conversationId] ?? []
        list.append(msg)
        messagesStore[conversationId] = list
        for (uid, var convos) in conversationsStore {
            if let idx = convos.firstIndex(where: { $0.id == conversationId }) {
                let old = convos[idx]
                convos[idx] = Conversation(id: old.id, title: old.title, participantIds: old.participantIds, lastMessagePreview: "[附件]", updatedAt: Date())
                conversationsStore[uid] = convos
            }
        }
        return msg
    }

    func conversation(id: String, for userId: String) async -> Conversation? {
        let list = conversationsStore[userId] ?? []
        return list.first(where: { $0.id == id })
    }
}
