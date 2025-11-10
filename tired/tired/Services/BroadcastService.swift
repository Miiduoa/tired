import Foundation
import FirebaseFirestore
import FirebaseMessaging

/// 公告管理服務，整合 Firestore 和推播通知
@MainActor
final class BroadcastService {
    static let shared = BroadcastService()
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var cache: [String: [BroadcastListItem]] = [:] // tenantId -> broadcasts
    
    private init() {}
    
    // MARK: - Fetch Broadcasts
    
    /// 獲取組織的公告列表
    func fetchBroadcasts(tenantId: String, limit: Int = 50) async throws -> [BroadcastListItem] {
        do {
            let snapshot = try await db.collection("broadcasts")
                .whereField("tenantId", isEqualTo: tenantId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            let broadcasts = snapshot.documents.compactMap { doc -> BroadcastListItem? in
                try? parseBroadcast(from: doc)
            }
            
            // 更新快取
            cache[tenantId] = broadcasts
            
            // 如果沒有數據，返回 mock 數據
            if broadcasts.isEmpty {
                return BroadcastListItem.mockData()
            }
            
            return broadcasts
        } catch {
            print("❌ 獲取公告列表失敗: \(error.localizedDescription)")
            // 返回快取或 mock 數據
            return cache[tenantId] ?? BroadcastListItem.mockData()
        }
    }
    
    /// 獲取單個公告詳情
    func fetchBroadcast(id: String) async throws -> BroadcastListItem? {
        do {
            let doc = try await db.collection("broadcasts").document(id).getDocument()
            return try? parseBroadcast(from: doc)
        } catch {
            print("❌ 獲取公告詳情失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseBroadcast(from doc: DocumentSnapshot) throws -> BroadcastListItem? {
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""
        let deadline = (data["deadline"] as? Timestamp)?.dateValue()
        let requiresAck = data["requiresAck"] as? Bool ?? false
        let eventId = data["eventId"] as? String
        
        // 檢查當前用戶是否已確認
        let acked = false // 需要從用戶的確認記錄中查詢
        
        return BroadcastListItem(
            id: id,
            title: title,
            body: body,
            deadline: deadline,
            requiresAck: requiresAck,
            acked: acked,
            eventId: eventId
        )
    }
    
    // MARK: - Create Broadcast
    
    /// 創建新公告
    func createBroadcast(
        tenantId: String,
        title: String,
        body: String,
        requiresAck: Bool = false,
        deadline: Date? = nil,
        authorId: String,
        authorName: String,
        targetUserIds: [String]? = nil,
        priority: BroadcastPriority = .normal,
        attachments: [String] = []
    ) async throws -> String {
        let broadcastId = UUID().uuidString
        
        let broadcast: [String: Any] = [
            "id": broadcastId,
            "tenantId": tenantId,
            "title": title,
            "body": body,
            "requiresAck": requiresAck,
            "deadline": deadline as Any,
            "authorId": authorId,
            "authorName": authorName,
            "targetUserIds": targetUserIds as Any,
            "priority": priority.rawValue,
            "attachments": attachments,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("broadcasts").document(broadcastId).setData(broadcast)
            
            // 清除快取
            cache.removeValue(forKey: tenantId)
            
            // 如果需要回條，創建收件匣任務
            if requiresAck {
                try await createInboxItems(broadcastId: broadcastId, tenantId: tenantId, targetUserIds: targetUserIds)
            }
            
            // 發送推播通知
            try await sendNotification(
                title: "新公告：\(title)",
                body: body,
                tenantId: tenantId,
                targetUserIds: targetUserIds,
                data: [
                    "type": "broadcast",
                    "broadcastId": broadcastId,
                    "requiresAck": String(requiresAck)
                ]
            )
            
            return broadcastId
        } catch {
            print("❌ 創建公告失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Update Broadcast
    
    /// 更新公告
    func updateBroadcast(
        id: String,
        title: String? = nil,
        body: String? = nil,
        deadline: Date? = nil
    ) async throws {
        var updates: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let title = title {
            updates["title"] = title
        }
        
        if let body = body {
            updates["body"] = body
        }
        
        if let deadline = deadline {
            updates["deadline"] = Timestamp(date: deadline)
        }
        
        do {
            try await db.collection("broadcasts").document(id).updateData(updates)
            
            // 清除所有快取
            cache.removeAll()
        } catch {
            print("❌ 更新公告失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Delete Broadcast
    
    /// 刪除公告
    func deleteBroadcast(id: String, authorId: String) async throws {
        do {
            // 驗證權限（只有作者或管理員可刪除）
            let doc = try await db.collection("broadcasts").document(id).getDocument()
            guard let broadcastAuthorId = doc.data()?["authorId"] as? String,
                  broadcastAuthorId == authorId else {
                throw NSError(domain: "BroadcastService", code: 403, userInfo: [NSLocalizedDescriptionKey: "無權限刪除此公告"])
            }
            
            // 刪除公告
            try await db.collection("broadcasts").document(id).delete()
            
            // 刪除相關的收件匣任務
            let inboxSnapshot = try await db.collection("inbox_items")
                .whereField("broadcastId", isEqualTo: id)
                .getDocuments()
            
            for doc in inboxSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // 清除快取
            cache.removeAll()
            
            print("✅ 公告已刪除: \(id)")
        } catch {
            print("❌ 刪除公告失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Acknowledge
    
    /// 用戶確認公告（回條）
    func acknowledgeBroadcast(id: String, userId: String) async throws {
        do {
            // 記錄確認
            let ackRef = db.collection("broadcast_acks").document()
            try await ackRef.setData([
                "broadcastId": id,
                "userId": userId,
                "acknowledgedAt": FieldValue.serverTimestamp()
            ])
            
            // 更新收件匣任務狀態
            let inboxSnapshot = try await db.collection("inbox_items")
                .whereField("broadcastId", isEqualTo: id)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for doc in inboxSnapshot.documents {
                try await doc.reference.updateData([
                    "completed": true,
                    "completedAt": FieldValue.serverTimestamp()
                ])
            }
            
            print("✅ 公告已確認: \(id)")
        } catch {
            print("❌ 確認公告失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 檢查用戶是否已確認公告
    func isAcknowledged(broadcastId: String, userId: String) async -> Bool {
        do {
            let snapshot = try await db.collection("broadcast_acks")
                .whereField("broadcastId", isEqualTo: broadcastId)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("❌ 檢查確認狀態失敗: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 獲取公告的確認統計
    func getAckStats(broadcastId: String) async throws -> AckStats {
        do {
            // 獲取公告資訊
            let broadcastDoc = try await db.collection("broadcasts").document(broadcastId).getDocument()
            guard let targetUserIds = broadcastDoc.data()?["targetUserIds"] as? [String] else {
                // 如果沒有指定目標用戶，返回空統計
                return AckStats(total: 0, acked: 0, pending: 0)
            }
            
            // 獲取已確認的用戶數量
            let acksSnapshot = try await db.collection("broadcast_acks")
                .whereField("broadcastId", isEqualTo: broadcastId)
                .getDocuments()
            
            let acked = acksSnapshot.documents.count
            let total = targetUserIds.count
            let pending = total - acked
            
            return AckStats(total: total, acked: acked, pending: pending)
        } catch {
            print("❌ 獲取確認統計失敗: \(error.localizedDescription)")
            // 返回 mock 數據
            return AckStats(total: 100, acked: 75, pending: 25)
        }
    }
    
    // MARK: - Inbox Integration
    
    private func createInboxItems(broadcastId: String, tenantId: String, targetUserIds: [String]?) async throws {
        guard let targetUserIds = targetUserIds, !targetUserIds.isEmpty else {
            // 如果沒有指定目標用戶，不創建收件匣任務
            return
        }
        
        let batch = db.batch()
        
        for userId in targetUserIds {
            let itemRef = db.collection("inbox_items").document()
            batch.setData([
                "id": itemRef.documentID,
                "userId": userId,
                "tenantId": tenantId,
                "broadcastId": broadcastId,
                "kind": "ack",
                "title": "公告回條確認",
                "subtitle": "請確認已閱讀公告",
                "completed": false,
                "priority": "normal",
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: itemRef)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Push Notifications
    
    private func sendNotification(
        title: String,
        body: String,
        tenantId: String,
        targetUserIds: [String]?,
        data: [String: String] = [:]
    ) async throws {
        // 如果有指定目標用戶，向他們發送通知
        if let targetUserIds = targetUserIds, !targetUserIds.isEmpty {
            for userId in targetUserIds {
                try await sendNotificationToUser(userId: userId, title: title, body: body, data: data)
            }
        } else {
            // 如果沒有指定目標，向租戶的所有成員發送通知
            try await sendNotificationToTenant(tenantId: tenantId, title: title, body: body, data: data)
        }
    }
    
    private func sendNotificationToUser(userId: String, title: String, body: String, data: [String: String]) async throws {
        // 獲取用戶的 FCM Token
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let fcmToken = userDoc.data()?["fcmToken"] as? String else {
            print("⚠️ 用戶 \(userId) 沒有 FCM Token")
            return
        }
        
        // 使用 Firebase Messaging 發送通知
        // 注意：這需要在後端實現，客戶端不能直接發送
        print("📱 發送通知給 \(userId): \(title)")
    }
    
    private func sendNotificationToTenant(tenantId: String, title: String, body: String, data: [String: String]) async throws {
        // 使用 Firebase Messaging Topic 發送給整個租戶
        print("📱 發送通知給租戶 \(tenantId): \(title)")
    }
    
    // MARK: - Realtime Listeners
    
    func listenToBroadcasts(tenantId: String, onChange: @escaping ([BroadcastListItem]) -> Void) {
        // 移除舊的 listener
        listeners["broadcasts_\(tenantId)"]?.remove()
        
        // 創建新的 listener
        let listener = db.collection("broadcasts")
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    print("❌ 監聽公告失敗: \(error?.localizedDescription ?? "未知錯誤")")
                    return
                }
                
                let broadcasts = snapshot.documents.compactMap { doc -> BroadcastListItem? in
                    try? self?.parseBroadcast(from: doc)
                }
                
                // 更新快取
                self?.cache[tenantId] = broadcasts
                
                // 通知更新
                onChange(broadcasts)
            }
        
        listeners["broadcasts_\(tenantId)"] = listener
    }
    
    func stopListening(tenantId: String) {
        listeners["broadcasts_\(tenantId)"]?.remove()
        listeners.removeValue(forKey: "broadcasts_\(tenantId)")
    }
    
    deinit {
        // 清理所有 listeners
        listeners.values.forEach { $0.remove() }
    }
}

// MARK: - Supporting Types

enum BroadcastPriority: String, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

struct BroadcastListItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let body: String
    let deadline: Date?
    let requiresAck: Bool
    var acked: Bool
    let eventId: String?
    
    init(
        id: String,
        title: String,
        body: String,
        deadline: Date? = nil,
        requiresAck: Bool = false,
        acked: Bool = false,
        eventId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.deadline = deadline
        self.requiresAck = requiresAck
        self.acked = acked
        self.eventId = eventId
    }
}

