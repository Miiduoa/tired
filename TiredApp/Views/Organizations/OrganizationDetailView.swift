import SwiftUI
import Combine

@available(iOS 17.0, *)
struct OrganizationDetailView: View {
    let organization: Organization

    @StateObject private var viewModel: OrganizationDetailViewModel
    @State private var selectedTab: DetailTab = .overview

    enum DetailTab: String, CaseIterable {
        case overview = "簡介"
        case posts = "動態"
        case apps = "小應用"
    }

    init(organization: Organization) {
        self.organization = organization
        self._viewModel = StateObject(wrappedValue: OrganizationDetailViewModel(organization: organization))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with cover image
                ZStack(alignment: .bottomLeading) {
                    // Cover image
                    if let coverUrl = organization.coverUrl {
                        AsyncImage(url: URL(string: coverUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        .frame(height: 150)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 150)
                    }

                    // Avatar overlay
                    HStack(alignment: .bottom, spacing: 12) {
                        if let avatarUrl = organization.avatarUrl {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                avatarPlaceholder
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        } else {
                            avatarPlaceholder
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(organization.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)

                                if organization.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                }
                            }

                            Text(organization.type.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 2)
                        }
                        .padding(.bottom, 8)

                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Action buttons
                HStack(spacing: 12) {
                    if viewModel.isMember {
                        // 成員管理按鈕（僅管理員及以上）
                        if viewModel.canManageMembers {
                            Button {
                                viewModel.showingMemberManagement = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("成員管理")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }

                        Button {
                            viewModel.showLeaveConfirmation = true
                        } label: {
                            Text("退出組織")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appSecondaryBackground)
                                .cornerRadius(8)
                        }
                    } else {
                        Button {
                            viewModel.joinOrganization()
                        } label: {
                            Text("加入組織")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()

                // Tab selector
                Picker("視圖", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Divider()
                    .padding(.top, 8)

                // Tab content
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .overview:
                        OverviewTab(organization: organization, viewModel: viewModel)
                    case .posts:
                        PostsTab(viewModel: viewModel)
                    case .apps:
                        AppsTab(viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingMemberManagement) {
            if let membership = viewModel.currentMembership {
                MemberManagementView(organization: organization, currentMembership: membership)
            }
        }
        .alert("退出組織", isPresented: $viewModel.showLeaveConfirmation) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                viewModel.leaveOrganization()
            }
        } message: {
            if viewModel.currentMembership?.role == .owner {
                Text("你是此組織的擁有者。退出後，所有權將自動轉移給下一位最高層級的成員。")
            } else {
                Text("確定要退出此組織嗎？")
            }
        }
        .alert(item: $viewModel.alertConfig) { config in
            Alert(
                title: Text(config.title),
                message: Text(config.message),
                dismissButton: .default(Text("確定"))
            )
        }
    }

    private var avatarPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(organization.name.prefix(2)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
            )
    }
}

// MARK: - Overview Tab

@available(iOS 17.0, *)
struct OverviewTab: View {
    let organization: Organization
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("關於")
                    .font(.system(size: 16, weight: .semibold))

                if let description = organization.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text("暫無介紹")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            // My role
            if viewModel.isMember, let membership = viewModel.currentMembership {
                VStack(alignment: .leading, spacing: 8) {
                    Text("我的身份")
                        .font(.system(size: 16, weight: .semibold))

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text(membership.role.displayName)
                            .font(.system(size: 14))

                        if let title = membership.title {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(title)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Posts Tab

@available(iOS 17.0, *)
struct PostsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("組織動態")
                .font(.system(size: 16, weight: .semibold))

            if viewModel.posts.isEmpty {
                Text("暫無動態")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post)
                }
            }
        }
    }
}

// MARK: - Apps Tab

@available(iOS 17.0, *)
struct AppsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小應用")
                .font(.system(size: 16, weight: .semibold))

            if viewModel.apps.isEmpty {
                Text("暫未啟用任何小應用")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.apps) { app in
                    AppInstanceCard(app: app, organizationId: viewModel.organization.id ?? "")
                }
            }
        }
    }
}

// MARK: - Post Card View

@available(iOS 17.0, *)
struct PostCardView: View {
    let post: Post

    @State private var showingComments = false
    @State private var reactionCount = 0
    @State private var commentCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Time
            Text(post.createdAt.formatShort())
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Content
            Text(post.contentText)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            // Actions
            HStack(spacing: 20) {
                Button {
                    // TODO: Implement like functionality
                } label: {
                    Label("\(reactionCount)", systemImage: "heart")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Button {
                    showingComments = true
                } label: {
                    Label("\(commentCount)", systemImage: "bubble.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showingComments) {
            CommentsView(post: post)
        }
        .task {
            await loadCounts()
        }
    }

    private func loadCounts() async {
        guard let postId = post.id else { return }

        // Load reaction count
        do {
            let reactionSnapshot = try await FirebaseManager.shared.db
                .collection("postReactions")
                .whereField("postId", isEqualTo: postId)
                .getDocuments()

            await MainActor.run {
                self.reactionCount = reactionSnapshot.documents.count
            }
        } catch {
            print("❌ Error loading reactions: \(error)")
        }

        // Load comment count
        do {
            let commentSnapshot = try await FirebaseManager.shared.db
                .collection("comments")
                .whereField("postId", isEqualTo: postId)
                .getDocuments()

            await MainActor.run {
                self.commentCount = commentSnapshot.documents.count
            }
        } catch {
            print("❌ Error loading comments: \(error)")
        }
    }
}

// MARK: - App Instance Card

@available(iOS 17.0, *)
struct AppInstanceCard: View {
    let app: OrgAppInstance
    let organizationId: String

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                Image(systemName: iconForTemplate(app.templateKey))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name ?? app.templateKey.displayName)
                        .font(.system(size: 15, weight: .medium))

                    Text(descriptionForTemplate(app.templateKey))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch app.templateKey {
        case .taskBoard:
            TaskBoardView(appInstance: app, organizationId: organizationId)
        case .eventSignup:
            EventSignupView(appInstance: app, organizationId: organizationId)
        case .resourceList:
            Text("資源列表（開發中）")
        }
    }

    private func iconForTemplate(_ key: OrgAppTemplateKey) -> String {
        switch key {
        case .taskBoard: return "checklist"
        case .eventSignup: return "calendar.badge.plus"
        case .resourceList: return "folder"
        }
    }

    private func descriptionForTemplate(_ key: OrgAppTemplateKey) -> String {
        switch key {
        case .taskBoard: return "查看和管理組織任務"
        case .eventSignup: return "查看活動並報名"
        case .resourceList: return "瀏覽共享資源"
        }
    }
}

// MARK: - Organization Detail ViewModel

class OrganizationDetailViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var apps: [OrgAppInstance] = []
    @Published var currentMembership: Membership?
    @Published var isMember = false
    @Published var showingMemberManagement = false
    @Published var showLeaveConfirmation = false
    @Published var alertConfig: AlertConfig?

    let organization: Organization
    private let postService = PostService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    var canManageMembers: Bool {
        currentMembership?.hasPermission(.manageMembers) ?? false
    }

    init(organization: Organization) {
        self.organization = organization
        setupSubscriptions()
        checkMembership()
    }

    private func setupSubscriptions() {
        guard let orgId = organization.id else { return }

        // 訂閱組織貼文
        postService.fetchOrganizationPosts(organizationId: orgId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] posts in
                    self?.posts = posts
                }
            )
            .store(in: &cancellables)

        // 獲取小應用
        Task {
            await fetchApps()
        }
    }

    private func fetchApps() async {
        guard let orgId = organization.id else { return }

        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("orgAppInstances")
                .whereField("organizationId", isEqualTo: orgId)
                .whereField("isEnabled", isEqualTo: true)
                .getDocuments()

            let apps = snapshot.documents.compactMap { doc -> OrgAppInstance? in
                try? doc.data(as: OrgAppInstance.self)
            }

            await MainActor.run {
                self.apps = apps
            }
        } catch {
            print("❌ Error fetching apps: \(error)")
        }
    }

    private func checkMembership() {
        guard let userId = userId, let orgId = organization.id else { return }

        Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: orgId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.currentMembership = membership
                        self.isMember = true
                    }
                }
            } catch {
                print("❌ Error checking membership: \(error)")
            }
        }
    }

    func joinOrganization() {
        guard let userId = userId, let orgId = organization.id else { return }

        Task {
            do {
                let membership = Membership(
                    userId: userId,
                    organizationId: orgId,
                    role: .member
                )

                try await organizationService.createMembership(membership)

                await MainActor.run {
                    self.isMember = true
                }

                checkMembership()
            } catch {
                print("❌ Error joining organization: \(error)")
            }
        }
    }

    func leaveOrganization() {
        guard let membership = currentMembership else { return }

        Task {
            do {
                // 使用新的繼任機制處理離開
                try await organizationService.handleMemberLeave(membership: membership)

                await MainActor.run {
                    self.isMember = false
                    self.currentMembership = nil
                    self.alertConfig = AlertConfig(
                        title: "成功",
                        message: membership.role == .owner ? "已退出組織並轉移所有權" : "已退出組織",
                        type: .success
                    )
                }
            } catch {
                print("❌ Error leaving organization: \(error)")
                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "錯誤",
                        message: "退出組織失敗：\(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }
}
