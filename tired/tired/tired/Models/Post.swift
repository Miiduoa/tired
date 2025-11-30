import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Post Type Enum (NEW)
enum PostType: String, Codable {
    case post         // A regular post by a member
    case announcement // An official announcement by a role with permission
}

// MARK: - Post

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    var authorUserId: String
    var organizationId: String?  // nil = 个人贴文

    var contentText: String
    var imageUrls: [String]?

    var visibility: PostVisibility
    var postType: PostType = .post // NEW

    // Moodle-like discussion features
    var isPinned: Bool = false              // 置頂
    var category: String?                    // 主題分類（例如：「公告」、「討論」、「問題」）
    var tags: [String]?                      // 標籤
    var readByUserIds: [String]?            // 已讀用戶 ID 列表

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorUserId
        case organizationId
        case contentText
        case imageUrls
        case visibility
        case postType // NEW
        case isPinned
        case category
        case tags
        case readByUserIds
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        authorUserId: String,
        organizationId: String? = nil,
        contentText: String,
        imageUrls: [String]? = nil,
        visibility: PostVisibility = .public,
        postType: PostType = .post, // NEW
        isPinned: Bool = false,
        category: String? = nil,
        tags: [String]? = nil,
        readByUserIds: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorUserId = authorUserId
        self.organizationId = organizationId
        self.contentText = contentText
        self.imageUrls = imageUrls
        self.visibility = visibility
        self.postType = postType // NEW
        self.isPinned = isPinned
        self.category = category
        self.tags = tags
        self.readByUserIds = readByUserIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Helper Methods

    /// 檢查用戶是否已讀
    func isReadBy(userId: String) -> Bool {
        return readByUserIds?.contains(userId) ?? false
    }

    /// 未讀數量（供管理員查看）
    var unreadCount: Int {
        // 這需要結合組織成員總數來計算
        return 0 // Placeholder
    }
}

// MARK: - Comment

struct Comment: Codable, Identifiable {
    @DocumentID var id: String?
    var postId: String
    var authorUserId: String
    var contentText: String
    var mentionedUserIds: [String]? // For @mentions

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case authorUserId
        case contentText
        case mentionedUserIds
        case createdAt
        case updatedAt
    }
}

// MARK: - Reaction

struct Reaction: Codable, Identifiable {
    @DocumentID var id: String?
    var postId: String
    var userId: String
    var type: String  // "like"

    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case userId
        case type
        case createdAt
    }
}

// MARK: - Post with Author (for UI)

struct PostWithAuthor: Identifiable {
    let post: Post
    let author: UserProfile?
    let organization: Organization?
    let reactionCount: Int
    let commentCount: Int
    let hasUserReacted: Bool

    var id: String? { post.id }
}
