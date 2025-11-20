import SwiftUI
import PhotosUI

@available(iOS 17.0, *)
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingCreatePost = false

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
                                    Task {
                                        await viewModel.toggleReaction(post: postWithAuthor)
                                    }
                                },
                                onDelete: {
                                    Task {
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
    let onDelete: () -> Void

    @State private var showingComments = false

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

                Button {
                    showingComments = true
                } label: {
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
        .sheet(isPresented: $showingComments) {
            CommentsView(post: postWithAuthor.post)
        }
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
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isUploadingImages = false

    private let storageService = StorageService()

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

                Section {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 4, matching: .images) {
                        Label("選擇圖片", systemImage: "photo.on.rectangle.angled")
                    }

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            selectedImages.remove(at: index)
                                            selectedItems.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("圖片（選填，最多4張）")
                }
                .onChange(of: selectedItems) { newItems in
                    Task {
                        await loadImages(from: newItems)
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

        Task {
            do {
                // 上傳圖片（如果有）
                var imageUrls: [String] = []
                if !selectedImages.isEmpty {
                    isUploadingImages = true
                    imageUrls = try await uploadImages()
                    isUploadingImages = false
                }

                // 創建貼文
                try await viewModel.createPost(text: text, organizationId: selectedOrganization, imageUrls: imageUrls)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating post: \(error)")
                await MainActor.run {
                    isCreating = false
                    isUploadingImages = false
                }
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        await MainActor.run {
            self.selectedImages = images
        }
    }

    private func uploadImages() async throws -> [String] {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CreatePostView", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }

        var urls: [String] = []

        for image in selectedImages {
            // 調整大小和壓縮
            let resizedImage = storageService.resizeImage(image, maxDimension: 1200)
            guard let imageData = storageService.compressImage(resizedImage, maxSizeKB: 800) else {
                continue
            }

            // 上傳到 Firebase Storage
            let url = try await storageService.uploadPostImage(userId: userId, imageData: imageData)
            urls.append(url)
        }

        return urls
    }
}
