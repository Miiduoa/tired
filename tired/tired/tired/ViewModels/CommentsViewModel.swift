import Foundation
import Combine
import FirebaseAuth

// MARK: - Comment With Author

struct CommentWithAuthor: Identifiable {
    let comment: Comment
    let author: UserProfile?

    var id: String? { comment.id }
}

// MARK: - Comments ViewModel

class CommentsViewModel: ObservableObject {
    @Published var comments: [CommentWithAuthor] = []
    @Published var isSending = false
    @Published var commentToDelete: CommentWithAuthor? // New property for confirmation dialog
    @Published var post: Post? // To store the post for organizationId access

    private let postId: String
    private let postService = PostService()
    private let userService = UserService()
    private let permissionService = PermissionService() // Inject PermissionService
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init(postId: String) {
        self.postId = postId
        fetchPost() // Fetch the post details
        setupSubscriptions()
    }
    
    private func fetchPost() {
        _Concurrency.Task { @MainActor in
            do {
                self.post = try await postService.fetchPost(id: postId)
            } catch {
                print("❌ Error fetching post for comments: \(error)")
                ToastManager.shared.showToast(message: "無法載入貼文詳情: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func setupSubscriptions() {
        postService.fetchComments(postId: postId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] comments in
                    _Concurrency.Task {
                        await self?.enrichComments(comments)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func enrichComments(_ comments: [Comment]) async {
        var enriched: [CommentWithAuthor] = []

        for comment in comments {
            let author = try? await userService.fetchUserProfile(userId: comment.authorUserId)
            enriched.append(CommentWithAuthor(comment: comment, author: author))
        }

        await MainActor.run {
            self.comments = enriched
        }
    }

    func addComment(text: String) async -> Bool {
        guard let userId = userId else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            return false
        }
        
        // Permission check for adding comment in an organization post
        if let orgId = post?.organizationId {
            do {
                let hasPerm = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.createPostCommentInOrg)
                guard hasPerm else {
                    ToastManager.shared.showToast(message: "您沒有權限在此組織貼文下發表評論。", type: .error)
                    return false
                }
            } catch {
                ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
                return false
            }
        }

        await MainActor.run { isSending = true }

        do {
            try await postService.addComment(postId: postId, userId: userId, text: text)
            ToastManager.shared.showToast(message: "評論已發布！", type: .success)
            await MainActor.run { isSending = false }
            return true
        } catch {
            print("❌ Error adding comment: \(error)")
            ToastManager.shared.showToast(message: "發布評論失敗: \(error.localizedDescription)", type: .error)
            await MainActor.run { isSending = false }
            return false
        }
    }

    func deleteComment(_ comment: Comment) async -> Bool {
        guard let commentId = comment.id, let currentUserId = userId else { return false }

        do {
            var hasPermission = false
            if let orgId = post?.organizationId {
                // Check if user has permission to delete any comment in this organization post
                hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyPostCommentInOrg)
            } else {
                // If it's a personal post comment, check if current user is the author
                hasPermission = comment.authorUserId == currentUserId
                // Optional: For future, could also check for AppPermissions.deleteOwnComment
            }

            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限刪除此評論。", type: .error)
                return false
            }

            try await postService.deleteComment(id: commentId)
            ToastManager.shared.showToast(message: "評論已刪除！", type: .success)
            // Remove from local array
            await MainActor.run {
                comments.removeAll(where: { $0.comment.id == commentId })
            }
            return true
        } catch {
            print("❌ Error deleting comment: \(error)")
            ToastManager.shared.showToast(message: "刪除評論失敗: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    /// 判斷當前用戶是否可以刪除某個評論
    func canDelete(comment: CommentWithAuthor) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = post?.organizationId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyPostCommentInOrg)
            } catch {
                print("Error checking delete permission for organization comment: \(error)")
                return false
            }
        } else {
            // Personal post comment: only author can delete
            return comment.comment.authorUserId == currentUserId
        }
    }
}
