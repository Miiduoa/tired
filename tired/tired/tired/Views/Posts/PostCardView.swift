import SwiftUI
import FirebaseAuth

// MARK: - Post Card View (Canonical version for both Feed and Organization Details)

@available(iOS 17.0, *)
struct PostCardView: View {
    let post: Post
    var postWithAuthor: PostWithAuthor? // Optional: For richer display in Feed

    // Optional feed view model to allow CommentsView to update the same feed
    var feedViewModel: FeedViewModel? = nil

    // Callbacks for actions
    var onLike: (() async -> Bool)?
    var onComment: (() -> Void)?
    var onDelete: (() async -> Bool)?

    @State private var showingComments = false
    @State private var reactionCount = 0
    @State private var commentCount = 0
    @State private var hasUserReacted = false
    @State private var isProcessingLike = false

    private let postService = PostService()
    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            // Header (only for Feed, not for Organization Detail simple display)
            if let postWithAuthor = postWithAuthor {
                FeedPostHeader(postWithAuthor: postWithAuthor, onDelete: onDelete)
            }

            // Content
            Text(post.contentText)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap

            // Images (if any)
            if let imageUrls = post.imageUrls, !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppDesignSystem.paddingSmall) {
                        ForEach(imageUrls, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall))
                        }
                    }
                }
            }

            // Footer / Actions
            HStack(spacing: AppDesignSystem.paddingLarge) {
                // Like Button
                Button {
                    _Concurrency.Task {
                        guard !isProcessingLike else { return }
                        await MainActor.run { isProcessingLike = true }

                        defer {
                            _Concurrency.Task {
                                try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
                                await MainActor.run { isProcessingLike = false }
                            }
                        }

                        guard let postId = post.id else {
                            await MainActor.run { isProcessingLike = false }
                            return
                        }

                        do {
                            if let onLike {
                                let success = await onLike()
                                if success {
                                    await MainActor.run {
                                        if hasUserReacted {
                                            reactionCount = max(0, reactionCount - 1)
                                        } else {
                                            reactionCount += 1
                                        }
                                        hasUserReacted.toggle()
                                    }
                                } else {
                                    ToastManager.shared.showToast(message: "點讚失敗，請稍後再試。", type: .error)
                                }
                            } else if let userId = userId {
                                try await postService.toggleReaction(postId: postId, userId: userId)
                                // update local counts on success
                                await MainActor.run {
                                    if hasUserReacted {
                                        reactionCount = max(0, reactionCount - 1)
                                    } else {
                                        reactionCount += 1
                                    }
                                    hasUserReacted.toggle()
                                }
                            }
                        } catch {
                            print("❌ Error toggling reaction: \(error)")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isProcessingLike { ProgressView().scaleEffect(0.8) }
                        Label("\(reactionCount)", systemImage: hasUserReacted ? "heart.fill" : "heart")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(hasUserReacted ? .red : .secondary)
                    }
                }
                .buttonStyle(.plain) // Remove default button styling

                // Comment Button
                Button {
                    onComment?() // Use passed in action
                    showingComments = true // Also show sheet internally
                } label: {
                    Label("\(commentCount)", systemImage: "bubble.right")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
                
                // Timestamp
                Text(post.createdAt.formatShort())
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium) // Apply glassmorphic effect
        .sheet(isPresented: $showingComments) {
            // CommentsView needs postWithAuthor and feedViewModel
            if let postWithAuthor = postWithAuthor {
                // 使用傳入的 feedViewModel（若有），否則創建新的 FeedViewModel
                CommentsView(postWithAuthor: postWithAuthor, feedViewModel: feedViewModel ?? FeedViewModel())
            } else {
                // 對於簡單的post，創建一個基本的PostWithAuthor
                let basicPostWithAuthor = PostWithAuthor(
                    post: post,
                    author: nil,
                    organization: nil,
                    reactionCount: reactionCount,
                    commentCount: commentCount,
                    hasUserReacted: hasUserReacted
                )
                CommentsView(postWithAuthor: basicPostWithAuthor, feedViewModel: feedViewModel ?? FeedViewModel())
            }
        }
        .task {
            await loadCounts()
        }
    }

    private func loadCounts() async {
        guard let postId = post.id else { return }

        // 自動標記公告為已讀（Moodle-like 功能）
        if post.postType == .announcement, let userId = userId {
            // 檢查是否已讀，避免重複標記
            let isRead = post.isReadBy(userId: userId)
            if !isRead {
                do {
                    try await postService.markAsRead(postId: postId, userId: userId)
                } catch {
                    print("❌ Error marking post as read: \(error)")
                    // 不影響主要功能，只記錄錯誤
                }
            }
        }

        do {
            let reactionCount = try await postService.getReactionCount(postId: postId)
            var userReacted = false

            if let userId = userId {
                userReacted = try await postService.hasUserReacted(postId: postId, userId: userId)
            }

            await MainActor.run {
                self.reactionCount = reactionCount
                self.hasUserReacted = userReacted
            }
        } catch {
            print("❌ Error loading reactions: \(error)")
        }

        do {
            let commentCount = try await postService.getCommentCount(postId: postId)

            await MainActor.run {
                self.commentCount = commentCount
            }
        } catch {
            print("❌ Error loading comments: \(error)")
        }
    }

    private func toggleLike() {
        guard let postId = post.id, let userId = userId else { return }

        _Concurrency.Task {
            do {
                try await postService.toggleReaction(postId: postId, userId: userId)

                await MainActor.run {
                    if hasUserReacted {
                        reactionCount = max(0, reactionCount - 1)
                    } else {
                        reactionCount += 1
                    }
                    hasUserReacted.toggle()
                }
            } catch {
                print("❌ Error toggling reaction: \(error)")
            }
        }
    }
}

// MARK: - Feed Post Header (for PostCardView)
@available(iOS 17.0, *)
struct FeedPostHeader: View {
    let postWithAuthor: PostWithAuthor
    var onDelete: (() async -> Bool)?
    @State private var isProcessingDelete = false

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                )

            VStack(alignment: .leading, spacing: 2) {
                // Organization or Author Name
                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    if let org = postWithAuthor.organization {
                        Text(org.name)
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                            .foregroundColor(.primary)
                        if org.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(AppDesignSystem.accentColor)
                                .font(AppDesignSystem.captionFont)
                        }
                    } else if let author = postWithAuthor.author {
                        Text(author.name)
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text("未知用戶")
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }

                // Subtitle (Author if org post, or timestamp if personal)
                if postWithAuthor.organization != nil, let author = postWithAuthor.author {
                    Text(author.name)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                } else {
                    Text(postWithAuthor.post.createdAt.formatShort())
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            
            // Delete Button (if current user is author)
            if let userId = FirebaseAuth.Auth.auth().currentUser?.uid, postWithAuthor.post.authorUserId == userId {
                Menu {
                    Button(role: .destructive) {
                        _Concurrency.Task {
                            guard !isProcessingDelete else { return }
                            await MainActor.run { isProcessingDelete = true }
                            let success = await (onDelete?() ?? true)
                            if !success {
                                ToastManager.shared.showToast(message: "刪除貼文失敗，請稍後再試。", type: .error)
                            }
                            await MainActor.run { isProcessingDelete = false }
                        }
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    if isProcessingDelete {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.bottom, AppDesignSystem.paddingSmall)
    }
}
