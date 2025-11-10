import Foundation
import FirebaseFirestore
import UIKit

/// 統一的 Firestore 數據服務層，提供所有模塊的數據存取
@MainActor
final class FirestoreDataService {
    static let shared = FirestoreDataService()
    
    private let db = Firestore.firestore()
    private let fileUploadService = FileUploadService.shared
    
    private init() {
        // 配置 Firestore 設置
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
    }
    
    // MARK: - Collections
    
    private enum Collection {
        static let users = "users"
        static let tenants = "tenants"
        static let members = "members"
        static let broadcasts = "broadcasts"
        static let posts = "posts"
        static let comments = "comments"
        static let messages = "messages"
        static let conversations = "conversations"
        static let friends = "friends"
        static let friendRequests = "friend_requests"
        static let attendance = "attendance_sessions"
        static let attendanceChecks = "attendance_checks"
        static let clockRecords = "clock_records"
        static let clockSites = "clock_sites"
        static let events = "events"
        static let polls = "polls"
        static let esgRecords = "esg_records"
        static let inboxItems = "inbox_items"
        static let notifications = "notifications"
    }
    
    // MARK: - User Profile
    
    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection(Collection.users).document(userId).getDocument()
        return try? doc.data(as: UserProfile.self)
    }
    
    func updateUserProfile(userId: String, profile: UserProfile) async throws {
        try db.collection(Collection.users).document(userId).setData(from: profile, merge: true)
    }
    
    // MARK: - Tenants & Memberships
    
    func fetchTenant(tenantId: String) async throws -> Tenant? {
        let doc = try await db.collection(Collection.tenants).document(tenantId).getDocument()
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let name = data["name"] as? String ?? "未命名組織"
        let typeString = data["type"] as? String ?? "community"
        let type = TenantType(rawValue: typeString) ?? .community
        let logoURLString = data["logoURL"] as? String
        let metadata = data["metadata"] as? [String: String] ?? [:]
        
        return Tenant(
            id: id,
            name: name,
            type: type,
            logoURL: logoURLString.flatMap(URL.init(string:)),
            metadata: metadata
        )
    }
    
    func fetchMemberships(userId: String) async throws -> [TenantMembership] {
        let snapshot = try await db.collection(Collection.members)
            .whereField("uid", isEqualTo: userId)
            .getDocuments()
        
        var memberships: [TenantMembership] = []
        
        for doc in snapshot.documents {
            guard let membership = try? await parseMembership(from: doc) else { continue }
            memberships.append(membership)
        }
        
        return memberships.sorted { $0.tenant.name < $1.tenant.name }
    }
    
    private func parseMembership(from doc: QueryDocumentSnapshot) async throws -> TenantMembership? {
        let data = doc.data()
        
        guard let groupId = data["groupId"] as? String,
              let tenant = try await fetchTenant(tenantId: groupId) else {
            return nil
        }
        
        let roleString = data["role"] as? String ?? "member"
        let role = TenantMembership.Role(rawValue: roleString) ?? .member
        let capabilityPack = CapabilityPack.defaultPack(for: tenant.type)
        let metadata = data["metadata"] as? [String: String] ?? [:]
        
        return TenantMembership(
            id: groupId,
            tenant: tenant,
            role: role,
            capabilityPack: capabilityPack,
            metadata: metadata
        )
    }
    
    // MARK: - Broadcasts
    
    func fetchBroadcasts(tenantId: String, limit: Int = 50) async throws -> [BroadcastItem] {
        let snapshot = try await db.collection(Collection.broadcasts)
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: BroadcastItem.self)
        }
    }
    
    func createBroadcast(tenantId: String, broadcast: BroadcastItem) async throws {
        var newBroadcast = broadcast
        newBroadcast.tenantId = tenantId
        newBroadcast.createdAt = Date()
        
        try db.collection(Collection.broadcasts).document(broadcast.id).setData(from: newBroadcast)
    }
    
    func acknowledgeBroadcast(broadcastId: String, userId: String) async throws {
        let ref = db.collection(Collection.broadcasts).document(broadcastId)
        try await ref.updateData([
            "acknowledgedUsers": FieldValue.arrayUnion([userId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Posts & Social
    
    func fetchPosts(tenantId: String?, limit: Int = 50) async throws -> [Post] {
        var query: Query = db.collection(Collection.posts)
        
        if let tenantId {
            query = query.whereField("tenantId", isEqualTo: tenantId)
        }
        
        let snapshot = try await query
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Post.self)
        }
    }
    
    func createPost(post: Post) async throws {
        var newPost = post
        newPost.createdAt = Date()
        newPost.updatedAt = Date()
        
        try db.collection(Collection.posts).document(post.id).setData(from: newPost)
    }
    
    func likePost(postId: String, userId: String) async throws {
        let ref = db.collection(Collection.posts).document(postId)
        try await ref.updateData([
            "likes": FieldValue.arrayUnion([userId]),
            "likeCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        let ref = db.collection(Collection.posts).document(postId)
        try await ref.updateData([
            "likes": FieldValue.arrayRemove([userId]),
            "likeCount": FieldValue.increment(Int64(-1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Chat & Messages
    
    func fetchConversations(userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection(Collection.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Conversation.self)
        }
    }
    
    func fetchMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection(Collection.messages)
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Message.self)
        }
    }
    
    func sendMessage(message: Message) async throws {
        var newMessage = message
        newMessage.timestamp = Date()
        
        // 創建或更新對話
        let conversationRef = db.collection(Collection.conversations).document(message.conversationId)
        let conversationDoc = try await conversationRef.getDocument()
        
        if !conversationDoc.exists {
            // 創建新對話
            let conversation = Conversation(
                id: message.conversationId,
                participantIds: [message.senderId], // 需要從外部傳入完整參與者列表
                title: "",
                lastMessage: message.content,
                lastMessageTimestamp: newMessage.timestamp,
                unreadCount: 0
            )
            try conversationRef.setData(from: conversation)
        } else {
            // 更新現有對話
            try await conversationRef.updateData([
                "lastMessage": message.content,
                "lastMessageTimestamp": FieldValue.serverTimestamp()
            ])
        }
        
        // 保存訊息
        try db.collection(Collection.messages).document(message.id).setData(from: newMessage)
    }
    
    // MARK: - Friends
    
    func fetchFriends(userId: String) async throws -> [Friend] {
        let snapshot = try await db.collection(Collection.friends)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Friend.self)
        }
    }
    
    func fetchFriendRequests(userId: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection(Collection.friendRequests)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FriendRequest.self)
        }
    }
    
    func sendFriendRequest(from fromUserId: String, to toUserId: String) async throws {
        let request = FriendRequest(
            id: UUID().uuidString,
            from: FriendUser(id: fromUserId, displayName: "", photoURL: nil),
            createdAt: Date()
        )
        
        var requestData = try Firestore.Encoder().encode(request)
        requestData["fromUserId"] = fromUserId
        requestData["toUserId"] = toUserId
        requestData["status"] = "pending"
        
        try await db.collection(Collection.friendRequests).document(request.id).setData(requestData)
    }
    
    func acceptFriendRequest(requestId: String, userId: String, friendId: String) async throws {
        // 更新請求狀態
        try await db.collection(Collection.friendRequests).document(requestId).updateData([
            "status": "accepted"
        ])
        
        // 創建雙向好友關係
        let friend1 = db.collection(Collection.friends).document()
        let friend2 = db.collection(Collection.friends).document()
        
        try await friend1.setData([
            "userId": userId,
            "friendId": friendId,
            "since": FieldValue.serverTimestamp()
        ])
        
        try await friend2.setData([
            "userId": friendId,
            "friendId": userId,
            "since": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Attendance
    
    func createAttendanceSession(session: AttendanceSession) async throws {
        var newSession = session
        newSession.createdAt = Date()
        
        try db.collection(Collection.attendance).document(session.id).setData(from: newSession)
    }
    
    func fetchAttendanceSessions(tenantId: String, limit: Int = 20) async throws -> [AttendanceSession] {
        let snapshot = try await db.collection(Collection.attendance)
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: AttendanceSession.self)
        }
    }
    
    func checkInAttendance(sessionId: String, userId: String, location: Location?) async throws {
        let check = AttendanceCheck(
            id: UUID().uuidString,
            sessionId: sessionId,
            userId: userId,
            timestamp: Date(),
            location: location,
            status: .present
        )
        
        try db.collection(Collection.attendanceChecks).document(check.id).setData(from: check)
    }
    
    // MARK: - Clock In/Out
    
    func clockIn(userId: String, tenantId: String, siteId: String, location: Location) async throws {
        let record = ClockRecord(
            id: UUID().uuidString,
            userId: userId,
            tenantId: tenantId,
            siteId: siteId,
            clockInTime: Date(),
            location: location,
            status: .normal
        )
        
        try db.collection(Collection.clockRecords).document(record.id).setData(from: record)
    }
    
    func clockOut(recordId: String) async throws {
        try await db.collection(Collection.clockRecords).document(recordId).updateData([
            "clockOutTime": FieldValue.serverTimestamp()
        ])
    }
    
    func fetchClockRecords(userId: String, limit: Int = 30) async throws -> [ClockRecord] {
        let snapshot = try await db.collection(Collection.clockRecords)
            .whereField("userId", isEqualTo: userId)
            .order(by: "clockInTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: ClockRecord.self)
        }
    }
    
    // MARK: - ESG
    
    func createESGRecord(record: ESGRecord) async throws {
        var newRecord = record
        newRecord.createdAt = Date()
        
        try db.collection(Collection.esgRecords).document(record.id).setData(from: newRecord)
    }
    
    func fetchESGRecords(tenantId: String, limit: Int = 50) async throws -> [ESGRecord] {
        let snapshot = try await db.collection(Collection.esgRecords)
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: ESGRecord.self)
        }
    }
    
    // MARK: - Events & Polls
    
    func fetchEvents(tenantId: String, limit: Int = 50) async throws -> [Event] {
        let snapshot = try await db.collection(Collection.events)
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "startTime", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Event.self)
        }
    }
    
    func registerForEvent(eventId: String, userId: String) async throws {
        let ref = db.collection(Collection.events).document(eventId)
        try await ref.updateData([
            "registeredUsers": FieldValue.arrayUnion([userId]),
            "registeredCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func fetchPolls(tenantId: String, limit: Int = 50) async throws -> [Poll] {
        let snapshot = try await db.collection(Collection.polls)
            .whereField("tenantId", isEqualTo: tenantId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Poll.self)
        }
    }
    
    func voteOnPoll(pollId: String, userId: String, optionIndex: Int) async throws {
        let ref = db.collection(Collection.polls).document(pollId)
        try await ref.updateData([
            "votes.\(userId)": optionIndex,
            "totalVotes": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Inbox
    
    func fetchInboxItems(userId: String, tenantId: String?, limit: Int = 50) async throws -> [InboxItem] {
        var query: Query = db.collection(Collection.inboxItems)
            .whereField("userId", isEqualTo: userId)
        
        if let tenantId {
            query = query.whereField("tenantId", isEqualTo: tenantId)
        }
        
        let snapshot = try await query
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: InboxItem.self)
        }
    }
    
    func markInboxItemCompleted(itemId: String) async throws {
        try await db.collection(Collection.inboxItems).document(itemId).updateData([
            "completed": true,
            "completedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - File Upload
    
    /// 上傳圖片（使用 FileUploadService）
    func uploadImage(_ imageData: Data, path: String) async throws -> URL {
        // 將 Data 轉換為 UIImage
        guard let image = UIImage(data: imageData) else {
            throw NSError(domain: "FirestoreDataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法將數據轉換為圖片"])
        }
        
        // 使用 FileUploadService 上傳
        let urlString = try await fileUploadService.uploadImage(image, category: .image, compress: false)
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "FirestoreDataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的下載 URL"])
        }
        
        return url
    }
    
    /// 上傳檔案（使用 FileUploadService）
    func uploadFile(_ fileData: Data, path: String, contentType: String) async throws -> URL {
        // 創建臨時文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        // 根據 content type 確定副檔名
        let ext: String
        switch contentType.lowercased() {
        case "image/jpeg", "image/jpg":
            ext = "jpg"
        case "image/png":
            ext = "png"
        case "application/pdf":
            ext = "pdf"
        default:
            ext = "bin"
        }
        
        let fileURL = tempURL.appendingPathExtension(ext)
        
        do {
            // 寫入臨時文件
            try fileData.write(to: fileURL)
            
            // 使用 FileUploadService 上傳
            let urlString = try await fileUploadService.uploadFile(
                from: fileURL,
                category: .document
            )
            
            // 清理臨時文件
            try? FileManager.default.removeItem(at: fileURL)
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "FirestoreDataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的下載 URL"])
            }
            
            return url
        } catch {
            // 清理臨時文件
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
    }
    
    // MARK: - Realtime Listeners
    
    func listenToMessages(conversationId: String, onUpdate: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection(Collection.messages)
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                let messages = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
                onUpdate(messages)
            }
    }
    
    func listenToConversations(userId: String, onUpdate: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        return db.collection(Collection.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                let conversations = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Conversation.self)
                }
                onUpdate(conversations)
            }
    }
}

// MARK: - Models

struct UserProfile: Codable {
    var displayName: String
    var bio: String?
    var photoURL: String?
    var coverPhotoURL: String?
    var interests: [String]?
    var location: String?
}

struct BroadcastItem: Codable {
    let id: String
    var tenantId: String
    let title: String
    let body: String
    let authorId: String
    let authorName: String
    var createdAt: Date
    var updatedAt: Date?
    let deadline: Date?
    let requiresAck: Bool
    var acknowledgedUsers: [String]?
    let priority: String?
    let attachments: [String]?
}

struct AttendanceSession: Codable {
    let id: String
    let tenantId: String
    let title: String
    let qrCode: String?
    let startTime: Date
    let endTime: Date
    var createdAt: Date
    let location: Location?
}

struct AttendanceCheck: Codable {
    let id: String
    let sessionId: String
    let userId: String
    let timestamp: Date
    let location: Location?
    let status: AttendanceStatus
}

enum AttendanceStatus: String, Codable {
    case present
    case late
    case absent
}

struct ClockRecord: Codable {
    let id: String
    let userId: String
    let tenantId: String
    let siteId: String
    let clockInTime: Date
    var clockOutTime: Date?
    let location: Location
    let status: ClockStatus
}

enum ClockStatus: String, Codable {
    case normal
    case exception
    case pending
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
}

struct ESGRecord: Codable {
    let id: String
    let tenantId: String
    let category: String
    let value: Double
    let unit: String
    var createdAt: Date
    let description: String?
    let imageURL: String?
}

struct FriendRequest: Codable {
    let id: String
    let from: FriendUser
    let createdAt: Date
}

