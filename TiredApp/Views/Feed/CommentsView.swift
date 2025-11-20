import SwiftUI

@available(iOS 17.0, *)
struct CommentsView: View {
    let post: Post
    @StateObject private var viewModel: CommentsViewModel
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss

    init(post: Post) {
        self.post = post
        self._viewModel = StateObject(wrappedValue: CommentsViewModel(postId: post.id ?? ""))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("加載評論中...")
                        Spacer()
                    }
                } else if viewModel.comments.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("還沒有評論")
                            .font(.system(size: 18, weight: .semibold))
                        Text("成為第一個評論的人")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    // 評論列表
                    List {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                }

                Divider()

                // 輸入框
                HStack(spacing: 12) {
                    TextField("寫下你的評論...", text: $commentText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        postComment()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(commentText.isEmpty ? .gray : .blue)
                    }
                    .disabled(commentText.isEmpty)
                }
                .padding()
                .background(Color.appSecondaryBackground)
            }
            .navigationTitle("評論")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    private func postComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.addComment(text: text)
        commentText = ""
    }
}

// MARK: - Comment Row

@available(iOS 17.0, *)
struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 頭像占位符
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.authorUserId)
                        .font(.system(size: 14, weight: .semibold))
                    Text(comment.createdAt.formatShort())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(comment.contentText)
                .font(.system(size: 15))
                .padding(.leading, 44)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Comments ViewModel

class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false

    private let postService = PostService()
    private let postId: String

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(postId: String) {
        self.postId = postId
        loadComments()
    }

    func loadComments() {
        isLoading = true

        Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("comments")
                    .whereField("postId", isEqualTo: postId)
                    .order(by: "createdAt", descending: false)
                    .getDocuments()

                let comments = snapshot.documents.compactMap { doc -> Comment? in
                    try? doc.data(as: Comment.self)
                }

                await MainActor.run {
                    self.comments = comments
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading comments: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    func addComment(text: String) {
        guard let userId = userId, !postId.isEmpty else { return }

        Task {
            do {
                try await postService.addComment(postId: postId, userId: userId, text: text)
                loadComments()
            } catch {
                print("❌ Error adding comment: \(error)")
            }
        }
    }
}
