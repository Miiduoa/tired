import SwiftUI
import Combine
import FirebaseAuth

@available(iOS 17.0, *)
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingCreatePost = false
    @State private var selectedPostForComments: PostWithAuthor?

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView { // Still need NavigationView for navigation stack
                ScrollView {
                    LazyVStack(spacing: AppDesignSystem.paddingMedium) {
                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            ProgressView("載入動態...")
                                .padding()
                        } else if viewModel.posts.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, postWithAuthor in
                                PostCardView(
                                    post: postWithAuthor.post,
                                    postWithAuthor: postWithAuthor,
                                    feedViewModel: viewModel, // Pass the viewModel here
                                    onLike: {
                                        _Concurrency.Task { await viewModel.toggleReaction(post: postWithAuthor) }
                                    },
                                    onComment: { selectedPostForComments = postWithAuthor },
                                    onDelete: {
                                        viewModel.postToDelete = postWithAuthor
                                    }
                                )
                                .onAppear {
                                    if index == viewModel.posts.count - 1 {
                                        viewModel.loadMorePosts()
                                    }
                                }
                            }
                        }
                        
                        if viewModel.isPaginating {
                            ProgressView("載入更多...")
                                .padding()
                        }
                        
                        if let error = viewModel.errorMessage, !error.isEmpty && !viewModel.isLoading && viewModel.posts.isEmpty {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding(AppDesignSystem.paddingMedium)
                }
                .navigationTitle("動態墻")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCreatePost = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppDesignSystem.accentColor)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $showingCreatePost) {
                    CreatePostView(viewModel: viewModel)
                }
                .sheet(item: $selectedPostForComments) { postWithAuthor in
                    CommentsView(postWithAuthor: postWithAuthor, feedViewModel: viewModel) // Pass the viewModel here
                }
                .refreshable {
                    viewModel.refresh()
                }
                .background(Color.clear) // Make NavigationView's background clear to show ZStack background
                .confirmationDialog("刪除貼文", isPresented: Binding<Bool>(
                    get: { viewModel.postToDelete != nil },
                    set: { _ in viewModel.postToDelete = nil }
                )) {
                    Button("刪除", role: .destructive) {
                        if let post = viewModel.postToDelete {
                            _Concurrency.Task { await viewModel.deletePost(post: post) }
                        }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("您確定要刪除此貼文嗎？此操作無法撤銷。")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("動態墻空空如也")
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.primary)

            Text("加入組織或創建貼文，開始與他人互動")
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreatePost = true
            } label: {
                Text("發布動態")
            }
            .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusLarge, textColor: .white))
        }
        .padding(AppDesignSystem.paddingLarge)
        .glassmorphicCard()
        .padding(.top, AppDesignSystem.paddingLarge * 2) // Push it down a bit
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
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet
                
                Form {
                    Section {
                        TextEditor(text: $text)
                            .font(AppDesignSystem.bodyFont)
                            .padding(AppDesignSystem.paddingSmall)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                            .frame(height: 150)
                            .listRowBackground(Color.clear) // Make form row transparent
                    } header: {
                        Text("內容")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    } footer: {
                        Text("分享你的想法、公告或更新")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }

                    Section("發布為（選填）") {
                        Picker("發布身份", selection: $selectedOrganization) {
                            Text("個人動態").tag(nil as String?)

                            ForEach(orgViewModel.myMemberships, id: \.id) { membershipWithOrg in // Use \.id for ForEach
                                if let org = membershipWithOrg.organization, let orgId = org.id { // Corrected access here
                                    HStack {
                                        Text(org.name)
                                        if org.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(AppDesignSystem.accentColor)
                                        }
                                    }
                                    .tag(orgId as String?)
                                }
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                        .listRowBackground(Color.clear)
                    }
                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("發布動態")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("發布") {
                        createPost()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }

    private func createPost() {
        isCreating = true

        _Concurrency.Task {
            await viewModel.createPost(text: text, organizationId: selectedOrganization)
            await MainActor.run {
                dismiss()
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
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet

                VStack(spacing: 0) {
                    // Comments list
                    ScrollView {
                        LazyVStack(spacing: AppDesignSystem.paddingSmall) {
                            // Original post preview
                            postPreview
                                .padding(.horizontal, AppDesignSystem.paddingMedium)
                                .padding(.top, AppDesignSystem.paddingMedium)

                            Divider().background(Material.thin) // Glassy divider
                                .padding(.vertical, AppDesignSystem.paddingSmall)

                            // Comments
                            if viewModel.comments.isEmpty {
                                emptyState
                            } else {
                                ForEach(viewModel.comments) { commentWithAuthor in
                                    CommentRow(
                                        comment: commentWithAuthor,
                                        commentsViewModel: viewModel,
                                        onDelete: {
                                            // Trigger confirmation dialog
                                            viewModel.commentToDelete = commentWithAuthor
                                        }
                                    )
                                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                                }
                            }
                        }
                        .padding(.bottom, 80) // Make space for input bar
                    }

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("評論")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
            }
            .background(Color.clear) // Make NavigationView's background clear
            .confirmationDialog("刪除評論", isPresented: Binding<Bool>(
                get: { viewModel.commentToDelete != nil },
                set: { _ in viewModel.commentToDelete = nil }
            )) {
                Button("刪除", role: .destructive) {
                    if let comment = viewModel.commentToDelete {
                        _Concurrency.Task { await viewModel.deleteComment(comment.comment) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("您確定要刪除此評論嗎？此操作無法撤銷。")
            }
        }
    }

    private var postPreview: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack(spacing: AppDesignSystem.paddingSmall) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if let org = postWithAuthor.organization {
                        Text(org.name)
                            .font(AppDesignSystem.captionFont.weight(.semibold))
                            .foregroundColor(.primary)
                    } else if let author = postWithAuthor.author {
                        Text(author.name)
                            .font(AppDesignSystem.captionFont.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    Text(postWithAuthor.post.createdAt.formatShort())
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(postWithAuthor.post.contentText)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.primary)
                .lineLimit(3)
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("還沒有評論")
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.primary)

            Text("成為第一個評論的人吧！")
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
        }
        .padding(AppDesignSystem.paddingLarge)
        .glassmorphicCard()
        .padding(.top, AppDesignSystem.paddingLarge * 2)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Material.thin) // Glassy divider
            HStack(spacing: AppDesignSystem.paddingMedium) {
                TextField("寫下你的評論...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.primary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.vertical, AppDesignSystem.paddingSmall) // Add padding to match button

                Button {
                    sendComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppDesignSystem.accentColor)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal, AppDesignSystem.paddingMedium)
            .padding(.vertical, AppDesignSystem.paddingSmall)
            .background(Material.bar) // Apply material to the input bar
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
                feedViewModel.refresh() // Update comment count in feed
            }
        }
    }
}

// MARK: - Comment Row

@available(iOS 17.0, *)
struct CommentRow: View {
    let comment: CommentWithAuthor
    @ObservedObject var commentsViewModel: CommentsViewModel // Inject CommentsViewModel
    var onDelete: (() -> Void)? // Keep this for now, could be simplified later

    @State private var canDeleteComment = false

    var body: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
            NavigationLink(destination: ProfileView(userId: comment.author?.id)) {
                // Avatar and Author Info
                HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(comment.author?.name.prefix(1) ?? "?").uppercased())
                                .font(AppDesignSystem.captionFont.weight(.medium))
                                .foregroundColor(.secondary)
                        )

                    VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                        HStack {
                            Text(comment.author?.name ?? "用戶")
                                .font(AppDesignSystem.captionFont.weight(.semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Text(comment.comment.createdAt.formatShort())
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }

                        Text(comment.comment.contentText)
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain) // Remove default button styling for NavigationLink

            Spacer()

            // Delete Button (if current user has permission)
            if canDeleteComment {
                Menu {
                    Button(role: .destructive) {
                        onDelete?() // Use passed in action
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
        .task { // Use .task to asynchronously determine if delete button should be shown
            canDeleteComment = await commentsViewModel.canDelete(comment: comment)
        }
    }
}