import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 動態墻視圖的ViewModel
class FeedViewModel: ObservableObject {
    @Published var posts: [PostWithAuthor] = []
    @Published var isLoading = false // Initial loading state
    @Published var errorMessage: String?
    @Published var postToDelete: PostWithAuthor? // For confirmation dialog

    // Pagination properties
    @Published var isPaginating = false // For "load more" indicator
    @Published var canLoadMore = true   // If there are more posts to fetch
    private var lastDocument: DocumentSnapshot?
    private let paginationLimit = 10 // Number of posts per page

    private let postService = PostService()
    private let userService = UserService()
    private let organizationService = OrganizationService()
    private let permissionService = PermissionService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        loadInitialPosts() // Start loading posts on init
    }

    // MARK: - Post Loading

    func loadInitialPosts() {
        guard let userId = userId else { return } // User must be logged in

        isLoading = true
        isPaginating = false
        canLoadMore = true
        lastDocument = nil
        posts = [] // Clear existing posts for a fresh load

        _Concurrency.Task { await loadPosts(appending: false) }
    }

    func loadMorePosts() {
        guard canLoadMore, !isLoading, !isPaginating, let userId = userId else { return }

        isPaginating = true
        _Concurrency.Task { await loadPosts(appending: true) }
    }

    private func loadPosts(appending: Bool) async {
        guard let userId = userId else {
            await MainActor.run {
                isLoading = false
                isPaginating = false
                errorMessage = "用戶未登入"
                ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            }
            return
        }

        do {
            let (fetchedPosts, newLastDocument) = try await postService.fetchFeedPostsPaginated(
                userId: userId,
                limit: paginationLimit,
                lastDocumentSnapshot: lastDocument
            )

            let enriched = await enrichPosts(fetchedPosts)

            await MainActor.run {
                if appending {
                    self.posts.append(contentsOf: enriched)
                } else {
                    self.posts = enriched
                }
                self.lastDocument = newLastDocument
                self.canLoadMore = (fetchedPosts.count == paginationLimit)
                self.isLoading = false
                self.isPaginating = false
            }
        } catch {
            print("❌ Error loading posts: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.isPaginating = false
                self.errorMessage = "載入貼文失敗: \(error.localizedDescription)"
                ToastManager.shared.showToast(message: "載入貼文失敗: \(error.localizedDescription)", type: .error)
            }
        }
    }

    /// 豐富貼文信息（作者、組織、反應數等）
    private func enrichPosts(_ posts: [Post]) async -> [PostWithAuthor] {
        guard !posts.isEmpty else { return [] }
        
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
        
        // Ensure posts are sorted by creation date (most recent first)
        enrichedPosts.sort { $0.post.createdAt > $1.post.createdAt }
        
        return enrichedPosts
    }

    // MARK: - Actions

    /// 創建新貼文
    func createPost(text: String, organizationId: String?) async {
        guard let userId = userId else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            return
        }
        
        // Permission check for creating post in an organization
        if let orgId = organizationId {
            do {
                let hasPerm = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.createPostInOrg)
                guard hasPerm else {
                    ToastManager.shared.showToast(message: "您沒有權限在此組織中創建貼文。", type: .error)
                    return
                }
            } catch {
                ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
                return
            }
        }

        let post = Post(
            authorUserId: userId,
            organizationId: organizationId,
            contentText: text,
            visibility: organizationId != nil ? .orgMembers : .public
        )

        do {
            try await postService.createPost(post)
            ToastManager.shared.showToast(message: "貼文發布成功！", type: .success)
            let enriched = await enrichPosts([post])
            if let newPost = enriched.first {
                await MainActor.run { self.posts.insert(newPost, at: 0) } // Optimistically add new post
            }
        } catch {
            print("❌ Error creating post: \(error)")
            ToastManager.shared.showToast(message: "發布貼文失敗: \(error.localizedDescription)", type: .error)
        }
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
                    ToastManager.shared.showToast(message: updated.hasUserReacted ? "已點讚！" : "已取消點讚！", type: .success)
                }
            }
        } catch {
            print("❌ Error toggling reaction: \(error)")
            ToastManager.shared.showToast(message: "點讚失敗: \(error.localizedDescription)", type: .error)
        }
    }

    /// 刪除貼文
    func deletePost(post: PostWithAuthor) async {
        guard let postId = post.post.id, let currentUserId = userId else { return }

        do {
            var hasPermission = false
            if let orgId = post.post.organizationId {
                // Check if user has permission to delete any post in this organization
                hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyPostInOrg)
            } else {
                // If it's a personal post, check if current user is the author
                hasPermission = post.post.authorUserId == currentUserId
            }

            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限刪除此貼文。", type: .error)
                return
            }

            try await postService.deletePost(id: postId)
            ToastManager.shared.showToast(message: "貼文已刪除！", type: .success)
            // Remove from local array
            await MainActor.run {
                posts.removeAll(where: { $0.post.id == postId })
            }
        } catch {
            print("❌ Error deleting post: \(error)")
            ToastManager.shared.showToast(message: "刪除貼文失敗: \(error.localizedDescription)", type: .error)
        }
    }

    /// 判斷當前用戶是否可以刪除某個貼文
    func canDelete(post: PostWithAuthor) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = post.post.organizationId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyPostInOrg)
            } catch {
                print("Error checking delete permission for organization post: \(error)")
                return false
            }
        }
        else {
            // Personal post: only author can delete
            return post.post.authorUserId == currentUserId
        }
    }

    /// 重新載入 (for full refresh, not just load more)
    func refresh() {
        loadInitialPosts()
    }
}
