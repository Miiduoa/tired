import SwiftUI
import Combine

@available(iOS 17.0, *)
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingCreatePost = false
    @State private var selectedPostForComments: PostWithAuthor?

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.posts) { postWithAuthor in
                            FeedPostCard(
                                postWithAuthor: postWithAuthor,
                                onLike: {
                                    _Concurrency.Task {
                                        await viewModel.toggleReaction(post: postWithAuthor)
                                    }
                                },
                                onComment: {
                                    selectedPostForComments = postWithAuthor
                                },
                                onDelete: {
                                    _Concurrency.Task {
                                        await viewModel.deletePost(post: postWithAuthor)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("動態墻")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView(viewModel: viewModel)
            }
            .sheet(item: $selectedPostForComments) { postWithAuthor in
                CommentsView(postWithAuthor: postWithAuthor, feedViewModel: viewModel)
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("動態墻空空如也")
                .font(.system(size: 18, weight: .semibold))

            Text("加入組織或創建貼文，開始與他人互動")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreatePost = true
            } label: {
                Text("發布動態")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Feed Post Card

@available(iOS 17.0, *)
struct FeedPostCard: View {
    let postWithAuthor: PostWithAuthor
    let onLike: () -> Void
    let onComment: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if let org = postWithAuthor.organization {
                        HStack(spacing: 4) {
                            Text(org.name)
                                .font(.system(size: 14, weight: .semibold))

                            if org.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 10))
                            }
                        }
                    } else if let author = postWithAuthor.author {
                        Text(author.name)
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text("用戶")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    // 顯示作者名稱（如果有組織的話）
                    if postWithAuthor.organization != nil, let author = postWithAuthor.author {
                        Text(author.name)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text(postWithAuthor.post.createdAt.formatShort())
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // Content
            Text(postWithAuthor.post.contentText)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Images (if any)
            if let imageUrls = postWithAuthor.post.imageUrls, !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageUrls, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: postWithAuthor.hasUserReacted ? "heart.fill" : "heart")
                            .foregroundColor(postWithAuthor.hasUserReacted ? .red : .secondary)
                        Text("\(postWithAuthor.reactionCount)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.secondary)
                        Text("\(postWithAuthor.commentCount)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .font(.system(size: 13))
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Create Post View

@available(iOS 17.0, *)
struct CreatePostView: View {
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var orgViewModel = OrganizationsViewModel()
    @State private var text = ""
    @State private var selectedOrganization: String?
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(height: 150)
                } header: {
                    Text("內容")
                } footer: {
                    Text("分享你的想法、公告或更新")
                        .font(.caption)
                }

                Section("發布為（選填）") {
                    Picker("發布身份", selection: $selectedOrganization) {
                        Text("個人動態").tag(nil as String?)

                        ForEach(orgViewModel.myMemberships) { membershipWithOrg in
                            if let org = membershipWithOrg.organization, let orgId = org.id {
                                HStack {
                                    Text(org.name)
                                    if org.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .tag(orgId as String?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("發布動態")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("發布") {
                        createPost()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }

    private func createPost() {
        isCreating = true

        _Concurrency.Task {
            do {
                try await viewModel.createPost(text: text, organizationId: selectedOrganization)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating post: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Comments View

@available(iOS 17.0, *)
struct CommentsView: View {
    let postWithAuthor: PostWithAuthor
    @ObservedObject var feedViewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: CommentsViewModel
    @State private var newCommentText = ""
    @FocusState private var isInputFocused: Bool

    init(postWithAuthor: PostWithAuthor, feedViewModel: FeedViewModel) {
        self.postWithAuthor = postWithAuthor
        self.feedViewModel = feedViewModel
        self._viewModel = StateObject(wrappedValue: CommentsViewModel(postId: postWithAuthor.post.id ?? ""))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Original post preview
                        postPreview
                            .padding(.horizontal)
                            .padding(.top)

                        Divider()
                            .padding(.vertical, 8)

                        // Comments
                        if viewModel.comments.isEmpty {
                            emptyState
                        } else {
                            ForEach(viewModel.comments) { commentWithAuthor in
                                CommentRow(
                                    comment: commentWithAuthor,
                                    onDelete: {
                                        _Concurrency.Task {
                                            await viewModel.deleteComment(commentWithAuthor.comment)
                                        }
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Input bar
                inputBar
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

    private var postPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if let org = postWithAuthor.organization {
                        Text(org.name)
                            .font(.system(size: 13, weight: .semibold))
                    } else if let author = postWithAuthor.author {
                        Text(author.name)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(postWithAuthor.post.createdAt.formatShort())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(postWithAuthor.post.contentText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("還沒有評論")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("成為第一個評論的人吧！")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                TextField("寫下你的評論...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)

                Button {
                    sendComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    private func sendComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        _Concurrency.Task {
            await viewModel.addComment(text: text)
            await MainActor.run {
                newCommentText = ""
                isInputFocused = false
                // Update comment count in feed
                feedViewModel.refresh()
            }
        }
    }
}

// MARK: - Comment Row

@available(iOS 17.0, *)
struct CommentRow: View {
    let comment: CommentWithAuthor
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.author?.name.prefix(1) ?? "?").uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author?.name ?? "用戶")
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text(comment.comment.createdAt.formatShort())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(comment.comment.contentText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Comment With Author

struct CommentWithAuthor: Identifiable {
    let comment: Comment
    let author: UserProfile?

    var id: String? { comment.id }
}

// MARK: - Comments ViewModel

import FirebaseAuth

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
