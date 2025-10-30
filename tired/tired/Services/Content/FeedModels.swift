import Foundation

struct FeedCursor: Codable, Hashable {
    let lastDocumentID: String
    let lastCreatedAt: Date
}

struct FeedPage: Codable {
    let posts: [Post]
    let nextCursor: FeedCursor?
    
    init(posts: [Post], nextCursor: FeedCursor? = nil) {
        self.posts = posts
        self.nextCursor = nextCursor
    }
}

