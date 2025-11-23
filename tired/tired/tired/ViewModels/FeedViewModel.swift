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
    private let organizationService = OrganizationService()
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

    /// 豐富貼文信息（作者、組織、反應數等）- 優化版
    private func enrichPosts(_ posts: [Post]) async {
        guard !posts.isEmpty else {
            await MainActor.run { self.posts = [] }
            return
        }
        
        // 1. 收集所有需要的 IDs
        let authorIds = posts.map { $0.authorUserId }
        let orgIds = posts.compactMap { $0.organizationId }

        // 2. 一次性批量獲取用戶和組織資料
        async let usersTask = userService.fetchUserProfiles(userIds: Array(Set(authorIds)))
        async let orgsTask = organizationService.fetchOrganizations(ids: Array(Set(orgIds)))
        
        let (users, orgs) = await (try? usersTask, try? orgsTask)
        
        // 3. 異步處理每個貼文的附加信息
        var enrichedPosts: [PostWithAuthor] = await withTaskGroup(of: PostWithAuthor.self, returning: [PostWithAuthor].self) { group in
            for post in posts {
                group.addTask {
                    let author = users?[post.authorUserId]
                    let organization = post.organizationId.flatMap { orgs?[$0] }
                    
                    // 這些仍然是 N+1，但至少在單個貼文的上下文中並行執行
                    async let reactionCount = (try? await self.postService.getReactionCount(postId: post.id ?? "")) ?? 0
                    async let commentCount = (try? await self.postService.getCommentCount(postId: post.id ?? "")) ?? 0
                    async let hasUserReacted = (try? await self.postService.hasUserReacted(postId: post.id ?? "", userId: self.userId ?? "")) ?? false
                    
                    let (reactions, comments, reacted) = await (reactionCount, commentCount, hasUserReacted)
                    
                    return PostWithAuthor(
                        post: post,
                        author: author,
                        organization: organization,
                        reactionCount: reactions,
                        commentCount: comments,
                        hasUserReacted: reacted
                    )
                }
            }
            
            var results: [PostWithAuthor] = []
            for await enrichedPost in group {
                results.append(enrichedPost)
            }
            return results
        }
        
        // 4. 按原始順序排序
        let originalOrder = posts.compactMap { $0.id }
        enrichedPosts.sort {
            guard let firstId = $0.post.id, let secondId = $1.post.id,
                  let firstIndex = originalOrder.firstIndex(of: firstId),
                  let secondIndex = originalOrder.firstIndex(of: secondId) else {
                return false
            }
            return firstIndex < secondIndex
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
