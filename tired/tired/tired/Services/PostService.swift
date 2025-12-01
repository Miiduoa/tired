import Foundation
import FirebaseFirestore
import Combine

/// 貼文服務
class PostService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Posts

    /// 獲取動態墻貼文（用戶關注的組織 + 公開貼文）- 分頁版本
    func fetchFeedPostsPaginated(userId: String, limit: Int, lastDocumentSnapshot: DocumentSnapshot?) async throws -> (posts: [Post], lastDocumentSnapshot: DocumentSnapshot?) {
        var query: Query = db.collection("posts")
            .whereField("visibility", isEqualTo: PostVisibility.public.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let lastSnapshot = lastDocumentSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents.compactMap { doc -> Post? in
            try? doc.data(as: Post.self)
        }

        return (posts, snapshot.documents.last)
    }
    func fetchFeedPosts(userId: String) -> AnyPublisher<[Post], Error> {
        let subject = PassthroughSubject<[Post], Error>()

        // 簡化版：獲取所有公開貼文（按時間倒序）
        db.collection("posts")
            .whereField("visibility", isEqualTo: PostVisibility.public.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let posts = documents.compactMap { doc -> Post? in
                    try? doc.data(as: Post.self)
                }

                subject.send(posts)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 獲取組織的貼文
    func fetchOrganizationPosts(organizationId: String) -> AnyPublisher<[Post], Error> {
        let subject = PassthroughSubject<[Post], Error>()

        db.collection("posts")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let posts = documents.compactMap { doc -> Post? in
                    try? doc.data(as: Post.self)
                }

                subject.send(posts)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    /// 獲取單個貼文
    func fetchPost(id: String) async throws -> Post {
        let doc = try await db.collection("posts").document(id).getDocument()
        guard let post = try? doc.data(as: Post.self) else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }
        return post
    }

    /// 創建貼文
    func createPost(_ post: Post) async throws {
        var newPost = post
        newPost.createdAt = Date()
        newPost.updatedAt = Date()

        // 如果是公告類型，自動置頂
        if newPost.postType == .announcement {
            newPost.isPinned = true
        }

        _ = try db.collection("posts").addDocument(from: newPost)
    }

    /// 刪除貼文
    func deletePost(id: String) async throws {
        try await db.collection("posts").document(id).delete()
    }

    // MARK: - Moodle-like Discussion Features

    /// 置頂貼文
    func pinPost(postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "isPinned": true,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 取消置頂
    func unpinPost(postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "isPinned": false,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 標記貼文為已讀
    func markAsRead(postId: String, userId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "readByUserIds": FieldValue.arrayUnion([userId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 設定貼文分類
    func setCategory(postId: String, category: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "category": category,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 添加標籤
    func addTags(postId: String, tags: [String]) async throws {
        try await db.collection("posts").document(postId).updateData([
            "tags": FieldValue.arrayUnion(tags),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 獲取組織貼文（按置頂和時間排序）
    func fetchOrganizationPostsSorted(organizationId: String) -> AnyPublisher<[Post], Error> {
        let subject = PassthroughSubject<[Post], Error>()

        db.collection("posts")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                var posts = documents.compactMap { doc -> Post? in
                    try? doc.data(as: Post.self)
                }

                // 手動排序：置頂的在前面，然後按時間排序
                posts.sort { post1, post2 in
                    if post1.isPinned && !post2.isPinned {
                        return true
                    } else if !post1.isPinned && post2.isPinned {
                        return false
                    } else {
                        return post1.createdAt > post2.createdAt
                    }
                }

                subject.send(posts)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 按分類獲取貼文
    func fetchPostsByCategory(organizationId: String, category: String) -> AnyPublisher<[Post], Error> {
        let subject = PassthroughSubject<[Post], Error>()

        db.collection("posts")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("category", isEqualTo: category)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let posts = documents.compactMap { doc -> Post? in
                    try? doc.data(as: Post.self)
                }

                subject.send(posts)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Reactions

    /// 點讚/取消點讚
    func toggleReaction(postId: String, userId: String) async throws {
        // 檢查是否已點讚
        let snapshot = try await db.collection("reactions")
            .whereField("postId", isEqualTo: postId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        if let doc = snapshot.documents.first {
            // 已點讚，取消
            try await db.collection("reactions").document(doc.documentID).delete()
        } else {
            // 未點讚，新增
            let reaction = Reaction(
                id: nil,
                postId: postId,
                userId: userId,
                type: "like",
                createdAt: Date()
            )
            _ = try db.collection("reactions").addDocument(from: reaction)
        }
    }

    /// 獲取貼文的點讚數
    func getReactionCount(postId: String) async throws -> Int {
        let snapshot = try await db.collection("reactions")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        return snapshot.documents.count
    }

    /// 檢查用戶是否已點讚
    func hasUserReacted(postId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("reactions")
            .whereField("postId", isEqualTo: postId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }

    // MARK: - Comments

    /// 添加評論
    func addComment(postId: String, userId: String, text: String) async throws {
        let comment = Comment(
            id: nil,
            postId: postId,
            authorUserId: userId,
            contentText: text,
            createdAt: Date(),
            updatedAt: Date()
        )
        _ = try db.collection("comments").addDocument(from: comment)
    }

    /// 獲取貼文的評論數
    func getCommentCount(postId: String) async throws -> Int {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        return snapshot.documents.count
    }

    /// 獲取貼文的所有評論
    func fetchComments(postId: String) -> AnyPublisher<[Comment], Error> {
        let subject = PassthroughSubject<[Comment], Error>()

        db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let comments = documents.compactMap { doc -> Comment? in
                    try? doc.data(as: Comment.self)
                }

                subject.send(comments)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 刪除評論
    func deleteComment(id: String) async throws {
        try await db.collection("comments").document(id).delete()
    }
}
