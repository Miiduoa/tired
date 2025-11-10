import Foundation
import FirebaseFirestore

/// 統一收件匣服務
@MainActor
final class InboxService {
    static let shared = InboxService()
    
    private let db = Firestore.firestore()
    private var cache: [String: [InboxItem]] = [:] // userId -> items
    
    private init() {}
    
    // MARK: - Fetch Items
    
    /// 獲取收件匣任務列表
    func fetchItems(userId: String, tenantId: String?, completed: Bool? = nil) async throws -> [InboxItem] {
        do {
            var query: Query = db.collection("inbox_items")
                .whereField("userId", isEqualTo: userId)
            
            if let tenantId = tenantId {
                query = query.whereField("tenantId", isEqualTo: tenantId)
            }
            
            if let completed = completed {
                query = query.whereField("completed", isEqualTo: completed)
            }
            
            let snapshot = try await query
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let items = snapshot.documents.compactMap { doc -> InboxItem? in
                try? parseItem(from: doc)
            }
            
            // 更新快取
            cache[userId] = items
            
            // 如果沒有數據，返回 mock 數據
            if items.isEmpty {
                return await MockDataProvider.shared.mockInboxItems()
            }
            
            return items
        } catch {
            print("❌ 獲取收件匣失敗: \(error.localizedDescription)")
            // 返回快取或 mock 數據
            if let cached = cache[userId], !cached.isEmpty {
                return cached
            }
            return await MockDataProvider.shared.mockInboxItems()
        }
    }
    
    /// 獲取未完成任務數量
    func getUncompletedCount(userId: String, tenantId: String?) async throws -> Int {
        do {
            var query: Query = db.collection("inbox_items")
                .whereField("userId", isEqualTo: userId)
                .whereField("completed", isEqualTo: false)
            
            if let tenantId = tenantId {
                query = query.whereField("tenantId", isEqualTo: tenantId)
            }
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.count
        } catch {
            print("❌ 獲取未完成數量失敗: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func parseItem(from doc: DocumentSnapshot) throws -> InboxItem? {
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let kindString = data["kind"] as? String ?? "ack"
        let kind = InboxItem.Kind(rawValue: kindString) ?? .ack
        let title = data["title"] as? String ?? ""
        let subtitle = data["subtitle"] as? String ?? ""
        let deadline = (data["deadline"] as? Timestamp)?.dateValue()
        let priorityString = data["priority"] as? String ?? "normal"
        let priority = InboxItem.Priority(rawValue: priorityString) ?? .normal
        let completed = data["completed"] as? Bool ?? false
        
        return InboxItem(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            deadline: deadline,
            priority: priority,
            completed: completed
        )
    }
    
    // MARK: - Create Item
    
    /// 創建收件匣任務
    func createItem(
        userId: String,
        tenantId: String,
        kind: InboxItem.Kind,
        title: String,
        subtitle: String,
        deadline: Date? = nil,
        priority: InboxItem.Priority = .normal,
        metadata: [String: String] = [:]
    ) async throws -> String {
        let itemId = UUID().uuidString
        
        let itemData: [String: Any] = [
            "id": itemId,
            "userId": userId,
            "tenantId": tenantId,
            "kind": kind.rawValue,
            "title": title,
            "subtitle": subtitle,
            "deadline": deadline as Any,
            "priority": priority.rawValue,
            "completed": false,
            "metadata": metadata,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("inbox_items").document(itemId).setData(itemData)
            
            // 清除快取
            cache.removeValue(forKey: userId)
            
            print("✅ 收件匣任務已創建: \(itemId)")
            return itemId
        } catch {
            print("❌ 創建收件匣任務失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Update Item
    
    /// 標記任務完成
    func markCompleted(itemId: String, userId: String) async throws {
        do {
            try await db.collection("inbox_items").document(itemId).updateData([
                "completed": true,
                "completedAt": FieldValue.serverTimestamp()
            ])
            
            // 清除快取
            cache.removeValue(forKey: userId)
            
            print("✅ 任務已標記完成: \(itemId)")
        } catch {
            print("❌ 標記完成失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 刪除任務
    func deleteItem(itemId: String, userId: String) async throws {
        do {
            try await db.collection("inbox_items").document(itemId).delete()
            
            // 清除快取
            cache.removeValue(forKey: userId)
            
            print("✅ 任務已刪除: \(itemId)")
        } catch {
            print("❌ 刪除任務失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Batch Operations
    
    /// 批量標記完成
    func markMultipleCompleted(itemIds: [String], userId: String) async throws {
        let batch = db.batch()
        
        for itemId in itemIds {
            let ref = db.collection("inbox_items").document(itemId)
            batch.updateData([
                "completed": true,
                "completedAt": FieldValue.serverTimestamp()
            ], forDocument: ref)
        }
        
        do {
            try await batch.commit()
            
            // 清除快取
            cache.removeValue(forKey: userId)
            
            print("✅ 批量標記完成: \(itemIds.count) 個任務")
        } catch {
            print("❌ 批量標記失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 清除已完成的任務
    func clearCompleted(userId: String) async throws {
        do {
            let snapshot = try await db.collection("inbox_items")
                .whereField("userId", isEqualTo: userId)
                .whereField("completed", isEqualTo: true)
                .getDocuments()
            
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            
            try await batch.commit()
            
            // 清除快取
            cache.removeValue(forKey: userId)
            
            print("✅ 已清除 \(snapshot.documents.count) 個已完成任務")
        } catch {
            print("❌ 清除失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Integration with Other Services
    
    /// 從公告創建任務（由 BroadcastService 調用）
    func createItemFromBroadcast(
        userId: String,
        tenantId: String,
        broadcastId: String,
        title: String,
        deadline: Date?
    ) async throws -> String {
        return try await createItem(
            userId: userId,
            tenantId: tenantId,
            kind: .ack,
            title: "公告回條：\(title)",
            subtitle: "請確認已閱讀公告",
            deadline: deadline,
            priority: deadline != nil ? .high : .normal,
            metadata: ["broadcastId": broadcastId]
        )
    }
    
    /// 從出勤創建任務
    func createItemFromAttendance(
        userId: String,
        tenantId: String,
        sessionId: String,
        title: String,
        startTime: Date
    ) async throws -> String {
        return try await createItem(
            userId: userId,
            tenantId: tenantId,
            kind: .rollcall,
            title: "出勤點名：\(title)",
            subtitle: "請準時參加",
            deadline: startTime,
            priority: .normal,
            metadata: ["sessionId": sessionId]
        )
    }
    
    /// 從打卡創建任務
    func createItemFromClock(
        userId: String,
        tenantId: String,
        title: String = "打卡提醒"
    ) async throws -> String {
        return try await createItem(
            userId: userId,
            tenantId: tenantId,
            kind: .clockin,
            title: title,
            subtitle: "請記得打卡上班",
            deadline: Date(),
            priority: .urgent
        )
    }
}

// MARK: - Models

struct InboxItem: Identifiable, Codable {
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let deadline: Date?
    let priority: Priority
    var completed: Bool
    
    enum Kind: String, Codable, CaseIterable {
        case ack = "ack"
        case rollcall = "rollcall"
        case clockin = "clockin"
        case assignment = "assignment"
        case esgTask = "esgTask"
        case event = "event"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .ack: return "回條確認"
            case .rollcall: return "出勤點名"
            case .clockin: return "打卡提醒"
            case .assignment: return "作業任務"
            case .esgTask: return "ESG 任務"
            case .event: return "活動報名"
            case .other: return "其他"
            }
        }
        
        var icon: String {
            switch self {
            case .ack: return "checkmark.circle.fill"
            case .rollcall: return "person.badge.clock.fill"
            case .clockin: return "location.fill"
            case .assignment: return "doc.text.fill"
            case .esgTask: return "leaf.fill"
            case .event: return "calendar"
            case .other: return "tray.fill"
            }
        }
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case urgent = "urgent"
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .normal: return "一般"
            case .high: return "高"
            case .urgent: return "緊急"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .normal: return "blue"
            case .high: return "orange"
            case .urgent: return "red"
            }
        }
    }
    
    init(
        id: String,
        kind: Kind,
        title: String,
        subtitle: String,
        deadline: Date? = nil,
        priority: Priority = .normal,
        completed: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.deadline = deadline
        self.priority = priority
        self.completed = completed
    }
}

