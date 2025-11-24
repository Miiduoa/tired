import SwiftUI
import FirebaseAuth

// MARK: - Post Card View (Canonical version for both Feed and Organization Details)

@available(iOS 17.0, *)
struct PostCardView: View {
    let post: Post
    var postWithAuthor: PostWithAuthor? // Optional: For richer display in Feed
    
    // Callbacks for actions
    var onLike: (() async -> Void)?
    var onComment: (() -> Void)?
    var onDelete: (() async -> Void)?

    @State private var showingComments = false
    @State private var reactionCount = 0
    @State private var commentCount = 0
    @State private var hasUserReacted = false

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
                    onLike?()
                    toggleLike() // Also perform internal toggle
                } label: {
                    Label("\(reactionCount)", systemImage: hasUserReacted ? "heart.fill" : "heart")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(hasUserReacted ? .red : .secondary)
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
                CommentsView(postWithAuthor: postWithAuthor, feedViewModel: FeedViewModel()) // Pass a dummy FeedViewModel or refactor
            } else {
                CommentsView(post: post) // Fallback for simple post
            }
        }
        .task {
            await loadCounts()
        }
    }

    private func loadCounts() async {
        guard let postId = post.id else { return }

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

        Task {
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
    var onDelete: (() async -> Void)?

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
                                .font(.system(size: AppDesignSystem.captionFont.pointSize))
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
                        Task { await onDelete?() }
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, AppDesignSystem.paddingSmall)
    }
}
