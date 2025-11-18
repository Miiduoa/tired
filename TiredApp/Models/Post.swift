import Foundation
import FirebaseFirestore

// MARK: - Post

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    var authorUserId: String
    var organizationId: String?  // nil = 个人贴文

    var contentText: String
    var imageUrls: [String]?

    var visibility: PostVisibility

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorUserId
        case organizationId
        case contentText
        case imageUrls
        case visibility
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
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorUserId = authorUserId
        self.organizationId = organizationId
        self.contentText = contentText
        self.imageUrls = imageUrls
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Comment

struct Comment: Codable, Identifiable {
    @DocumentID var id: String?
    var postId: String
    var authorUserId: String
    var contentText: String

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case authorUserId
        case contentText
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
