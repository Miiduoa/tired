import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 動態墻視圖的ViewModel
class FeedViewModel: ObservableObject {
    @Published var posts: [PostWithAuthor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let postService = PostService()
    private let userService = UserService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let userId = userId else { return }

        postService.fetchFeedPosts(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching feed posts: \(error)")
                    }
                },
                receiveValue: { [weak self] posts in
                    // 為每個貼文獲取完整信息
                    guard let self = self else { return }
                    _Concurrency.Task {
                        await self.enrichPosts(posts)
                    }
                }
            )
            .store(in: &cancellables)
    }

    /// 豐富貼文信息（作者、組織、反應數等）
    private func enrichPosts(_ posts: [Post]) async {
        var enrichedPosts: [PostWithAuthor] = []

        for post in posts {
            // 獲取作者信息
            let author = try? await userService.fetchUserProfile(userId: post.authorUserId)

            // 獲取組織信息
            var organization: Organization? = nil
            if let orgId = post.organizationId {
                let doc = try? await FirebaseManager.shared.db
                    .collection("organizations")
                    .document(orgId)
                    .getDocument()
                organization = try? doc?.data(as: Organization.self)
            }

            // 獲取反應數和評論數
            let reactionCount = (try? await postService.getReactionCount(postId: post.id ?? "")) ?? 0
            let commentCount = (try? await postService.getCommentCount(postId: post.id ?? "")) ?? 0

            // 檢查當前用戶是否已點讚
            var hasUserReacted = false
            if let postId = post.id, let userId = userId {
                hasUserReacted = (try? await postService.hasUserReacted(postId: postId, userId: userId)) ?? false
            }

            enrichedPosts.append(PostWithAuthor(
                post: post,
                author: author,
                organization: organization,
                reactionCount: reactionCount,
                commentCount: commentCount,
                hasUserReacted: hasUserReacted
            ))
        }

        await MainActor.run {
            self.posts = enrichedPosts
        }
    }

    // MARK: - Actions

    /// 創建新貼文
    func createPost(text: String, organizationId: String?) async throws {
        guard let userId = userId else {
            throw NSError(domain: "FeedViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let post = Post(
            authorUserId: userId,
            organizationId: organizationId,
            contentText: text,
            visibility: organizationId != nil ? .orgMembers : .public
        )

        try await postService.createPost(post)
    }

    /// 點讚/取消點讚
    func toggleReaction(post: PostWithAuthor) async {
        guard let postId = post.post.id, let userId = userId else { return }

        do {
            try await postService.toggleReaction(postId: postId, userId: userId)

            // 更新本地狀態
            if let index = posts.firstIndex(where: { $0.post.id == postId }) {
                await MainActor.run {
                    var updated = posts[index]
                    updated = PostWithAuthor(
                        post: updated.post,
                        author: updated.author,
                        organization: updated.organization,
                        reactionCount: updated.hasUserReacted ? updated.reactionCount - 1 : updated.reactionCount + 1,
                        commentCount: updated.commentCount,
                        hasUserReacted: !updated.hasUserReacted
                    )
                    posts[index] = updated
                }
            }
        } catch {
            print("❌ Error toggling reaction: \(error)")
        }
    }

    /// 刪除貼文
    func deletePost(post: PostWithAuthor) async {
        guard let postId = post.post.id else { return }

        do {
            try await postService.deletePost(id: postId)
        } catch {
            print("❌ Error deleting post: \(error)")
        }
    }

    /// 重新載入
    func refresh() {
        setupSubscriptions()
    }
}
