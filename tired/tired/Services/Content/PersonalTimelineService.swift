import Foundation
import FirebaseFirestore

protocol PersonalTimelineServiceProtocol {
    func fetchPersonalPosts(for user: User) async -> [Post]
    func createPost(_ post: Post, for user: User) async throws
}

final class PersonalTimelineService: PersonalTimelineServiceProtocol {
    private let db = Firestore.firestore()
    private let cache = PostCache.shared
    private let cacheMaxAge: TimeInterval = 30
    
    func fetchPersonalPosts(for user: User) async -> [Post] {
        if let cached = await cache.personalPosts(for: user.id, maxAge: cacheMaxAge) {
            return cached
        }
        let collection = db.collection("users").document(user.id).collection("posts")
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
            .limit(to: 50)
        do {
            let snapshot = try await collection.getDocuments()
            let posts: [Post] = snapshot.documents.compactMap { FirestorePostMapper.post(from: $0) }
            await cache.setPersonalPosts(posts, for: user.id)
            return posts
        } catch {
            print("⚠️ 無法載入個人貼文：\(error.localizedDescription)")
            let fallback = [
                Post.samplePersonal(authorId: user.id)
            ]
            await cache.setPersonalPosts(fallback, for: user.id)
            return fallback
        }
    }
    
    func createPost(_ post: Post, for user: User) async throws {
        let data = FirestorePostMapper.makeDictionary(from: post, tenantId: post.metadata["tenantId"])
        let personalRef = db.collection("users").document(user.id).collection("posts").document(post.id)
        let globalRef = db.collection("posts").document(post.id)
        
        try await personalRef.setData(data, merge: false)
        if post.visibility != .privateOnly {
            try await globalRef.setData(data, merge: false)
        }
        await cache.invalidatePersonalPosts(for: user.id)
        await cache.invalidateFeed(for: nil)
    }
}
