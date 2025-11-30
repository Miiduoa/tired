import SwiftUI
import Combine
import FirebaseAuth

@available(iOS 17.0, *)
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingCreatePost = false
    @State private var selectedPostForComments: PostWithAuthor?
    @State private var isProcessingDeletePost = false

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
                                    feedViewModel: viewModel,
                                    onLike: { return await viewModel.toggleReaction(post: postWithAuthor) },
                                    onComment: { selectedPostForComments = postWithAuthor },
                                    onDelete: {
                                        // Set the pending delete and let FeedView handle confirmation
                                        await MainActor.run { viewModel.postToDelete = postWithAuthor }
                                        return true
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
                        _Concurrency.Task {
                            guard !isProcessingDeletePost, let post = viewModel.postToDelete else { return }
                            await MainActor.run { isProcessingDeletePost = true }
                            await viewModel.deletePost(post: post)
                            await MainActor.run {
                                isProcessingDeletePost = false
                                // 清除選擇的待刪除貼文，以關閉對話
                                viewModel.postToDelete = nil
                            }
                        }
                    }
                    Button("取消", role: .cancel) {
                        // 明確清除待刪除的貼文，確保 UI 有回應
                        viewModel.postToDelete = nil
                    }
                } message: {
                    if isProcessingDeletePost {
                        Text("正在刪除貼文，請稍候...")
                    } else {
                        Text("您確定要刪除此貼文嗎？此操作無法撤銷。")
                    }
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
    let defaultOrganizationId: String?
    let initialPostType: PostType
    @Environment(\.dismiss) private var dismiss

    @StateObject private var orgViewModel = OrganizationsViewModel()
    @State private var text = ""
    @State private var selectedOrganization: String?
    @State private var isCreating = false
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var imageUrls: [String] = []
    @State private var isUploadingImages = false
    @State private var isAnnouncement = false
    @State private var canCreateAnnouncement = false
    @State private var permissionService = PermissionService()
    
    // Draft support
    private let draftKey = "create_post_draft_v1"
    
    init(viewModel: FeedViewModel, defaultOrganizationId: String? = nil, initialPostType: PostType = .post) {
        self.viewModel = viewModel
        self.defaultOrganizationId = defaultOrganizationId
        self.initialPostType = initialPostType
    }

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

                    Section("圖片（選填）") {
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
                                                if index < imageUrls.count {
                                                    imageUrls.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.clear)
                        }
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("添加圖片")
                            }
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(AppDesignSystem.accentColor)
                        }
                        .listRowBackground(Color.clear)
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

                    Section("貼文類型") {
                        if canCreateAnnouncement {
                            Toggle("設為組織公告", isOn: $isAnnouncement)
                                .tint(AppDesignSystem.accentColor)
                        } else {
                            Text(selectedOrganization == nil ? "個人貼文" : "組織貼文")
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .background(Color.clear) // Make Form background clear

                // Loading overlay
                if isCreating || isUploadingImages {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(isUploadingImages ? "上傳圖片中..." : "發布中...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("發布動態")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("保存草稿") {
                        saveDraft()
                        AlertHelper.shared.showSuccess("草稿已儲存")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("發布") {
                        createPost()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating || isUploadingImages)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(images: $selectedImages, maxSelection: 9)
            }
            .onAppear {
                loadDraft()
                
                // Apply defaults when opened from an organization entry point
                if (selectedOrganization == nil || selectedOrganization?.isEmpty == true) {
                    selectedOrganization = defaultOrganizationId
                }
                if initialPostType == .announcement {
                    isAnnouncement = true
                }
                
                _Concurrency.Task { await checkAnnouncementPermission(for: selectedOrganization) }
            }
            .onChange(of: text) {
                saveDraft()
            }
            .onChange(of: selectedOrganization) { oldValue, newValue in
                _Concurrency.Task {
                    await checkAnnouncementPermission(for: newValue)
                }
                // If org changes, reset the announcement toggle
                isAnnouncement = false
                saveDraft()
            }
            .onChange(of: isAnnouncement) {
                saveDraft()
            }
        }
    }

    private func checkAnnouncementPermission(for orgId: String?) async {
        guard let orgId = orgId else {
            await MainActor.run { canCreateAnnouncement = false }
            return
        }
        
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.createAnnouncementInOrg)
            await MainActor.run {
                canCreateAnnouncement = hasPermission
            }
        } catch {
            print("Error checking announcement permission: \(error)")
            await MainActor.run {
                canCreateAnnouncement = false
            }
        }
    }

    private func createPost() {
        isCreating = true

        _Concurrency.Task {
            // 先上傳圖片（若有）
            if !selectedImages.isEmpty {
                isUploadingImages = true
                do {
                    imageUrls = try await uploadImages(selectedImages)
                } catch {
                    // 上傳失敗，顯示錯誤並允許重試
                    isUploadingImages = false
                    isCreating = false
                    AlertHelper.shared.showError("圖片上傳失敗：\(error.localizedDescription)")
                    return
                }
                isUploadingImages = false
            }

            // 創建貼文
            let postType: PostType = isAnnouncement ? .announcement : .post
            let success = await viewModel.createPost(text: text, organizationId: selectedOrganization, imageUrls: imageUrls.isEmpty ? nil : imageUrls, postType: postType)
            await MainActor.run {
                if success {
                    // 發布成功，刪除草稿並關閉
                    clearDraft()
                    dismiss()
                } else {
                    isCreating = false
                    AlertHelper.shared.showError("發布貼文失敗，請稍後重試。")
                }
            }
        }
    }
    
    private func uploadImages(_ images: [UIImage]) async throws -> [String] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        
        let storageService = StorageService()
        var urls: [String] = []
        for image in images {
            // 壓縮和調整圖片大小
            let resizedImage = storageService.resizeImage(image, maxDimension: 1200)
            guard let imageData = storageService.compressImage(resizedImage, maxSizeKB: 500) else { continue }

            do {
                let url = try await storageService.uploadPostImage(userId: userId, imageData: imageData)
                urls.append(url)
            } catch {
                // 若任一張上傳失敗，拋出錯誤讓上層處理（避免不完整的上傳導致使用者誤以為全部成功）
                throw error
            }
        }

        return urls
    }

    // MARK: - Draft methods
    private func saveDraft() {
        let dict: [String: String] = ["text": text, "org": selectedOrganization ?? ""]
        UserDefaults.standard.setValue(dict, forKey: draftKey)
    }

    private func loadDraft() {
        guard let dict = UserDefaults.standard.dictionary(forKey: draftKey) as? [String: String] else { return }
        if let savedText = dict["text"], !savedText.isEmpty {
            text = savedText
        }
        if let org = dict["org"], !org.isEmpty {
            selectedOrganization = org
        }
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}

// MARK: - Image Picker

import PhotosUI

@available(iOS 17.0, *)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    let maxSelection: Int
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = maxSelection
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.images.append(image)
                        }
                    }
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
    @State private var isProcessingDeleteComment = false
    @State private var isSendingLocal = false // Local UI state for send button

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
                                                    await MainActor.run { viewModel.commentToDelete = commentWithAuthor }
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
                set: { _ in _Concurrency.Task { await MainActor.run { viewModel.commentToDelete = nil } } }
            )) {
                Button("刪除", role: .destructive) {
                    _Concurrency.Task {
                        guard !isProcessingDeleteComment, let comment = viewModel.commentToDelete else { return }
                        await MainActor.run { isProcessingDeleteComment = true }
                        let success = await viewModel.deleteComment(comment.comment)
                        await MainActor.run { isProcessingDeleteComment = false }
                        if success {
                            // 清除待刪除狀態以關閉對話
                            viewModel.commentToDelete = nil
                            feedViewModel.refresh()
                        }
                        // if failed, keep the dialog open (or it will close and user can retry)
                    }
                }
                Button("取消", role: .cancel) {
                    // 明確清除待刪除的評論
                    viewModel.commentToDelete = nil
                }
            } message: {
                if isProcessingDeleteComment {
                    Text("正在刪除評論，請稍候...")
                } else {
                    Text("您確定要刪除此評論嗎？此操作無法撤銷。")
                }
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
                    if isSendingLocal || viewModel.isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppDesignSystem.accentColor)
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending || isSendingLocal)
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
            await MainActor.run { isSendingLocal = true }
            let success = await viewModel.addComment(text: text)
            await MainActor.run {
                if success {
                    newCommentText = ""
                    isInputFocused = false
                    feedViewModel.refresh() // Update comment count in feed
                }
                isSendingLocal = false
            }
        }
    }
}

// MARK: - Comment Row

@available(iOS 17.0, *)
struct CommentRow: View {
    let comment: CommentWithAuthor
    @ObservedObject var commentsViewModel: CommentsViewModel // Inject CommentsViewModel
    var onDelete: (() async -> Void)? // Use async closure so callers can await MainActor updates

    @State private var canDeleteComment = false

    var body: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
            if let authorId = comment.author?.id {
                NavigationLink(destination: UserProfileView(userId: authorId)) {
                    authorInfoView
                }
                .buttonStyle(.plain)
            } else {
                authorInfoView
            }

            Spacer()

            // Delete Button (if current user has permission)
            if canDeleteComment {
                    Menu {
                        Button(role: .destructive) {
                            _Concurrency.Task { await onDelete?() }
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
    
    private var authorInfoView: some View {
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
}
