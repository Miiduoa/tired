import SwiftUI

/// 現代化貼文卡片（心理學優化）
struct PostRowView: View {
    let post: Post
    @State private var liked: Bool = false
    @State private var likeCount: Int = 0
    @State private var showComments: Bool = false
    @State private var commentCount: Int = 0
    private let interaction: PostInteractionServiceProtocol = PostInteractionService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            // 作者信息區（視覺層級優化）
            HStack(spacing: TTokens.spacingMD) {
                AvatarRing(
                    imageURL: nil,
                    size: 44,
                    ringColor: post.sourceType == .personal ? .tint : .creative,
                    ringWidth: 2
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.labelPrimary)
                    
                    HStack(spacing: 6) {
                        if let org = post.organizationName {
                            Text(org)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("•")
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: {}) {
                        Label("收藏", systemImage: "bookmark")
                    }
                    Button(action: {}) {
                        Label("舉報", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.neutralLight.opacity(0.5), in: Circle())
                }
            }
            
            // 內容區（認知負荷優化）
            VStack(alignment: .leading, spacing: TTokens.spacingSM) {
                Text(post.summary)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.labelPrimary)
                
                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .lineSpacing(4)
            }
            
            // 附件區
            if !post.attachmentURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.attachmentURLs, id: \.absoluteString) { url in
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link.circle.fill")
                                        .foregroundStyle(Color.tint)
                                    Text(displayName(for: url))
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.tintUltraLight, in: Capsule())
                            }
                        }
                    }
                }
            }
            
            // 標籤區（格式塔相近性原理）
            HStack(spacing: 6) {
                TagBadge(
                    post.sourceType == .personal ? "個人" : "組織",
                    color: post.sourceType == .personal ? .tint : .creative,
                    icon: post.sourceType == .personal ? "person.fill" : "building.2.fill"
                )
                TagBadge(
                    post.category.displayName,
                    color: .mint,
                    icon: "tag.fill"
                )
                TagBadge(
                    post.visibility.label,
                    color: .orange,
                    icon: post.visibility.icon
                )
            }
            
            // 互動區（情感化設計）
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 8) {
                // 情感化按讚按鈕
                Button {
                    HapticFeedback.light()
                    Task {
                        liked.toggle()
                        likeCount += liked ? 1 : -1
                        if liked {
                            HapticFeedback.success()
                            await interaction.like(postId: post.id, userId: post.sourceId)
                        } else {
                            await interaction.unlike(postId: post.id, userId: post.sourceId)
                        }
                    }
                } label: {
                    EmotionalLikeButton(isLiked: $liked, count: $likeCount)
                }
                
                // 評論氣泡按鈕
                CommentBubbleButton(count: commentCount) {
                    HapticFeedback.light()
                    showComments = true
                }
                
                Spacer()
                
                // 分享按鈕
                ShareButton {
                    HapticFeedback.medium()
                    // TODO: 實際分享邏輯
                }
            }
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
        .task {
            likeCount = await interaction.likeCount(postId: post.id)
            liked = await interaction.isLiked(postId: post.id, userId: post.sourceId)
        }
    }
    
    private func displayName(for url: URL) -> String {
        url.lastPathComponent.isEmpty ? url.host ?? "連結" : url.lastPathComponent
    }
}
