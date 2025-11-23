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

    private let postId: String
    private let postService = PostService()
    private let userService = UserService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init(postId: String) {
        self.postId = postId
        setupSubscriptions()
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

    func addComment(text: String) async {
        guard let userId = userId else { return }

        await MainActor.run {
            isSending = true
        }

        do {
            try await postService.addComment(postId: postId, userId: userId, text: text)
        } catch {
            print("❌ Error adding comment: \(error)")
        }

        await MainActor.run {
            isSending = false
        }
    }

    func deleteComment(_ comment: Comment) async {
        guard let commentId = comment.id else { return }

        do {
            try await postService.deleteComment(id: commentId)
        } catch {
            print("❌ Error deleting comment: \(error)")
        }
    }
}
