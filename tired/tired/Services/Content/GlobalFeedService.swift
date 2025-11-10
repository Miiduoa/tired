import Foundation
import FirebaseFirestore

struct FeedFilter: Sendable, Equatable, Codable {
    var categories: [PostCategory] = []
    var visibility: PostVisibility?
    var onlyOrganizations: Bool = false
    var onlyPersonal: Bool = false
    
    fileprivate func cacheKey(for userId: String) -> String {
        let categoriesKey = categories.map(\.rawValue).sorted().joined(separator: ",")
        let visibilityKey = visibility?.rawValue ?? "all"
        return "\(userId)|\(categoriesKey)|\(visibilityKey)|org:\(onlyOrganizations)|personal:\(onlyPersonal)"
    }
}

protocol GlobalFeedServiceProtocol {
    func fetchPosts(for user: User, filter: FeedFilter, after cursor: FeedCursor?, limit: Int) async -> FeedPage
}

extension GlobalFeedServiceProtocol {
    func fetchPosts(for user: User, filter: FeedFilter) async -> [Post] {
        let page = await fetchPosts(for: user, filter: filter, after: nil, limit: 20)
        return page.posts
    }
}

final class GlobalFeedService: GlobalFeedServiceProtocol {
    private let db = Firestore.firestore()
    private let cache = PostCache.shared
    private let cacheMaxAge: TimeInterval = 20
    
    func fetchPosts(for user: User, filter: FeedFilter, after cursor: FeedCursor?, limit: Int) async -> FeedPage {
        let cacheKey = filter.cacheKey(for: user.id)
        if cursor == nil, let cached = await cache.feedPage(for: cacheKey, maxAge: cacheMaxAge) {
            return cached
        }
        
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
            .limit(to: limit)
        
        if filter.onlyOrganizations {
            query = query.whereField("sourceType", isEqualTo: PostSourceType.organization.rawValue)
        } else if filter.onlyPersonal {
            query = query.whereField("sourceType", isEqualTo: PostSourceType.personal.rawValue)
        }
        if let visibility = filter.visibility {
            query = query.whereField("visibility", isEqualTo: visibility.rawValue)
        }
        if !filter.categories.isEmpty {
            let raw = filter.categories.map(\.rawValue)
            if raw.count == 1, let first = raw.first {
                query = query.whereField("category", isEqualTo: first)
            } else {
                query = query.whereField("category", in: Array(raw.prefix(10)))
            }
        }
        if let cursor {
            query = query.start(after: [
                Timestamp(date: cursor.lastCreatedAt),
                cursor.lastDocumentID
            ])
        }
        
        do {
            let snapshot = try await query.getDocuments()
            let mapped: [(post: Post, documentID: String)] = snapshot.documents.compactMap { doc in
                guard let post = FirestorePostMapper.post(from: doc) else { return nil }
                return (post, doc.documentID)
            }
            let posts = mapped.map(\.post)
            let nextCursor: FeedCursor?
            if mapped.count == snapshot.documents.count, mapped.count == limit, let last = mapped.last {
                nextCursor = FeedCursor(lastDocumentID: last.documentID, lastCreatedAt: last.post.createdAt)
            } else {
                nextCursor = nil
            }
            let page = FeedPage(posts: posts, nextCursor: nextCursor)
            if cursor == nil {
                await cache.setFeedPage(page, for: cacheKey)
            }
            return page
        } catch {
            print("⚠️ 無法載入全域貼文：\(error.localizedDescription)")
            if cursor == nil {
                let fallback = FeedPage(posts: [
                    Post.sampleOrganization(),
                    Post.samplePersonal(authorId: user.id)
                ], nextCursor: nil)
                await cache.setFeedPage(fallback, for: cacheKey)
                return fallback
            } else {
                return FeedPage(posts: [], nextCursor: nil)
            }
        }
    }
}
