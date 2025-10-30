import Foundation
import FirebaseFirestore

final class ChatServiceFirestore: ChatServiceProtocol, ChatRealtimeListening, ReadsRealtimeListening {
    private let db = Firestore.firestore()

    func conversations(for userId: String) async -> [Conversation] {
        do {
            let snap = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .order(by: "updatedAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let pids = data["participantIds"] as? [String],
                      let updated = (data["updatedAt"] as? Timestamp)?.dateValue() else { return nil }
                let preview = data["lastMessagePreview"] as? String ?? ""
                return Conversation(id: doc.documentID, title: title, participantIds: pids, lastMessagePreview: preview, updatedAt: updated)
            }
        } catch {
            return await ChatService.shared.conversations(for: userId)
        }
    }

    func messages(in conversationId: String, limit: Int) async -> [Message] {
        do {
            let snap = try await db.collection("conversations").document(conversationId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let items: [Message] = snap.documents.compactMap { doc in
                let data = doc.data()
                guard let senderId = data["senderId"] as? String,
                      let senderName = data["senderName"] as? String,
                      let text = data["text"] as? String,
                      let created = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                let attachments = data["attachments"] as? [String] ?? []
                return Message(id: doc.documentID, conversationId: conversationId, senderId: senderId, senderName: senderName, text: text, createdAt: created, attachments: attachments)
            }
            return items.sorted { $0.createdAt < $1.createdAt }
        } catch {
            return await ChatService.shared.messages(in: conversationId, limit: limit)
        }
    }

    func send(conversationId: String, from userId: String, name: String, text: String) async throws -> Message {
        let now = Date()
        let msgRef = db.collection("conversations").document(conversationId).collection("messages").document()
        let payload: [String: Any] = [
            "senderId": userId,
            "senderName": name,
            "text": text,
            "attachments": [],
            "createdAt": Timestamp(date: now)
        ]
        try await msgRef.setData(payload)
        let convRef = db.collection("conversations").document(conversationId)
        _ = try? await convRef.setData([
            "lastMessagePreview": text,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return Message(id: msgRef.documentID, conversationId: conversationId, senderId: userId, senderName: name, text: text, createdAt: now, attachments: [])
    }

    func createConversation(participantIds: [String], title: String) async throws -> Conversation {
        let ref = db.collection("conversations").document()
        let now = Date()
        try await ref.setData([
            "title": title,
            "participantIds": participantIds,
            "updatedAt": Timestamp(date: now),
            "lastMessagePreview": ""
        ])
        return Conversation(id: ref.documentID, title: title, participantIds: participantIds, lastMessagePreview: "", updatedAt: now)
    }

    func markRead(conversationId: String, userId: String) async {
        let ref = db.collection("conversations").document(conversationId).collection("reads").document(userId)
        _ = try? await ref.setData(["lastReadAt": FieldValue.serverTimestamp(), "uid": userId], merge: true)
    }

    func unreadCount(conversationId: String, userId: String, sampleLimit: Int) async -> Int {
        do {
            let readsRef = db.collection("conversations").document(conversationId).collection("reads").document(userId)
            let readsSnap = try? await readsRef.getDocument()
            let lastReadAt = (readsSnap?.data()? ["lastReadAt"] as? Timestamp)?.dateValue() ?? Date(timeIntervalSince1970: 0)
            let msgQuery = db.collection("conversations").document(conversationId).collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: sampleLimit)
            let snap = try await msgQuery.getDocuments()
            let count = snap.documents.reduce(0) { partial, doc in
                let created = (doc.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date(timeIntervalSince1970: 0)
                return partial + (created > lastReadAt ? 1 : 0)
            }
            return count
        } catch {
            return 0
        }
    }

    func sendAttachment(conversationId: String, from userId: String, name: String, attachmentURLs: [String]) async throws -> Message {
        let now = Date()
        let msgRef = db.collection("conversations").document(conversationId).collection("messages").document()
        let payload: [String: Any] = [
            "senderId": userId,
            "senderName": name,
            "text": "",
            "attachments": attachmentURLs,
            "createdAt": Timestamp(date: now)
        ]
        try await msgRef.setData(payload)
        let convRef = db.collection("conversations").document(conversationId)
        _ = try? await convRef.setData([
            "lastMessagePreview": "[附件]",
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return Message(id: msgRef.documentID, conversationId: conversationId, senderId: userId, senderName: name, text: "", createdAt: now, attachments: attachmentURLs)
    }

    @discardableResult
    func listenConversations(for userId: String, onChange: @escaping ([Conversation]) -> Void) -> CancelableToken? {
        let query = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .limit(to: 50)
        let reg = query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let items: [Conversation] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let pids = data["participantIds"] as? [String] else { return nil }
                let updated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                let preview = data["lastMessagePreview"] as? String ?? ""
                return Conversation(id: doc.documentID, title: title, participantIds: pids, lastMessagePreview: preview, updatedAt: updated)
            }
            onChange(items)
        }
        return FirebaseListenerToken(inner: reg)
    }

    @discardableResult
    func listenMessages(in conversationId: String, limit: Int, onChange: @escaping ([Message]) -> Void) -> CancelableToken? {
        let query = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        let reg = query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let items: [Message] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let senderId = data["senderId"] as? String,
                      let senderName = data["senderName"] as? String,
                      let text = data["text"] as? String,
                      let created = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                let attachments = data["attachments"] as? [String] ?? []
                return Message(id: doc.documentID, conversationId: conversationId, senderId: senderId, senderName: senderName, text: text, createdAt: created, attachments: attachments)
            }
            onChange(items.sorted { $0.createdAt < $1.createdAt })
        }
        return FirebaseListenerToken(inner: reg)
    }

    @discardableResult
    func listenAllReads(for userId: String, onChange: @escaping ([String: Date]) -> Void) -> CancelableToken? {
        let query = db.collectionGroup("reads").whereField("uid", isEqualTo: userId)
        let reg = query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            var map: [String: Date] = [:]
            for doc in snapshot.documents {
                let parent = doc.reference.parent.parent // conversations/{cid}
                guard let cid = parent?.documentID else { continue }
                let ts = (doc.data()["lastReadAt"] as? Timestamp)?.dateValue()
                if let ts { map[cid] = ts } else { map[cid] = Date(timeIntervalSince1970: 0) }
            }
            onChange(map)
        }
        return FirebaseListenerToken(inner: reg)
    }
}

enum ChatServiceRouter {
    static func make() -> ChatServiceProtocol {
        // Prefer Firestore; fall back to demo store on error
        ChatServiceFirestore()
    }
}

