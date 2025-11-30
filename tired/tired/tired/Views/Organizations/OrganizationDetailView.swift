import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct OrganizationDetailView: View {
    @StateObject private var viewModel: OrganizationDetailViewModel
    @StateObject private var feedViewModel = FeedViewModel()
    
    @State private var selectedTab: DetailTab = .overview
    @State private var showingManageApps = false
    @State private var showingMembershipRequests = false
    @State private var showingRoleManagement = false
    @State private var showingSettings = false
    @State private var isProcessingLeave = false
    @State private var isProcessingJoinRequest = false

    @State private var isChatViewActive = false
    @State private var chatRoomId: String?
    @State private var isLoadingChat = false
    @State private var chatErrorMessage: String?
    
    @State private var showingCreatePost = false
    @State private var createPostAsAnnouncement = false
    
    @State private var taskBoardApp: OrgAppInstance?
    @State private var eventSignupApp: OrgAppInstance?
    @State private var isNavigatingToTaskBoard = false
    @State private var isNavigatingToEventSignup = false
    @State private var isGeneratingInvite = false

    enum DetailTab: String, CaseIterable {
        case overview = "簡介", posts = "動態", apps = "小應用"
    }

    init(organizationId: String) {
        _viewModel = StateObject(wrappedValue: OrganizationDetailViewModel(organizationId: organizationId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("正在載入組織...")
            } else if let organization = viewModel.organization {
                content(for: organization)
                    .navigationDestination(isPresented: $showingRoleManagement) {
                        if let org = viewModel.organization {
                            RoleManagementView(organization: org)
                        }
                    }
                    .navigationDestination(isPresented: $isChatViewActive) {
                        if let roomId = chatRoomId {
                            ChatView(chatRoomId: roomId)
                        }
                    }
            } else {
                Text("無法載入組織資訊")
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if viewModel.canManageMembers {
                        Button {
                            showingMembershipRequests = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        
                        Button {
                            shareInvite()
                        } label: {
                            if isGeneratingInvite {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isGeneratingInvite)
                    }
                    
                    if viewModel.canManageApps {
                        Button {
                            showingManageApps = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    
                    if viewModel.canChangeRoles {
                        Button {
                            showingRoleManagement = true
                        } label: {
                            Image(systemName: "shield.righthalf.filled")
                        }
                    }
                    
                    if viewModel.canEditOrgInfo || viewModel.canManageMembers || viewModel.canChangeRoles || viewModel.canManageApps || viewModel.canDeleteOrganization {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            OrganizationSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingManageApps) {
            ManageAppsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingMembershipRequests) {
            if let orgId = viewModel.organization?.id {
                MembershipRequestsView(organizationId: orgId)
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView(
                viewModel: feedViewModel,
                defaultOrganizationId: viewModel.organizationId,
                initialPostType: createPostAsAnnouncement ? PostType.announcement : PostType.post
            )
        }
        .alert("無法開啟群組聊天", isPresented: Binding(
            get: { chatErrorMessage != nil },
            set: { _ in chatErrorMessage = nil }
        )) {
            Button("知道了", role: .cancel) { chatErrorMessage = nil }
        } message: {
            Text(chatErrorMessage ?? "請稍後再試。")
        }
    }

    private func content(for organization: Organization) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                navigationLinks
                
                header(for: organization)
                
                actionButtons
                    .padding()
                
                tabSelector
                
                Divider().padding(.top, 8)
                
                tabContent(for: organization)
                    .padding()
            }
        }
    }
    
    private var navigationLinks: some View {
        Group {
            NavigationLink(isActive: $isNavigatingToTaskBoard) {
                if let app = taskBoardApp {
                    TaskBoardView(appInstance: app, organizationId: viewModel.organizationId)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }
            .hidden()
            
            NavigationLink(isActive: $isNavigatingToEventSignup) {
                if let app = eventSignupApp {
                    EventSignupView(appInstance: app, organizationId: viewModel.organizationId)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }
            .hidden()
        }
    }

    private func header(for organization: Organization) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image
            if let coverUrl = organization.coverUrl {
                AsyncImage(url: URL(string: coverUrl)) { $0.resizable().scaledToFill() }
                placeholder: { coverPlaceholder }
                .frame(height: 150).clipped()
            } else {
                coverPlaceholder
            }

            // Avatar and Title overlay
            HStack(alignment: .bottom, spacing: 12) {
                if let avatarUrl = organization.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { $0.resizable().scaledToFill() }
                    placeholder: { avatarPlaceholder(for: organization) }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 3))
                } else {
                    avatarPlaceholder(for: organization)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(organization.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white).shadow(radius: 2)

                        if organization.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue).font(.system(size: 16))
                        }
                    }
                    Text(organization.type.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9)).shadow(radius: 2)
                }
                .padding(.bottom, 8)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 4) {
            if viewModel.isMember {
                HStack(spacing: 12) {
                    Button(action: startGroupChat) {
                        HStack {
                            if isLoadingChat { ProgressView().scaleEffect(0.9) }
                            Label("群組聊天", systemImage: "message.fill")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appSecondaryBackground)
                        .cornerRadius(8)
                    }
                    .disabled(isLoadingChat)

                    Button {
                        _Concurrency.Task {
                            guard !isProcessingLeave else { return }
                            await MainActor.run { isProcessingLeave = true }
                            let _ = await viewModel.leaveOrganizationAsync()
                            await MainActor.run { isProcessingLeave = false }
                        }
                    } label: {
                        HStack {
                            if isProcessingLeave { ProgressView().scaleEffect(0.9) }
                            Text("退出組織")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appSecondaryBackground)
                        .cornerRadius(8)
                    }
                    .disabled(isProcessingLeave)
                }
                
                roleQuickActions
            } else {
                Button {
                    _Concurrency.Task {
                        guard !isProcessingJoinRequest else { return }
                        isProcessingJoinRequest = true
                        let success = await viewModel.requestToJoinOrganizationAsync()
                        isProcessingJoinRequest = false
                        if success {
                            // UI state is updated inside ViewModel
                        }
                    }
                } label: {
                    HStack {
                        if isProcessingJoinRequest {
                            ProgressView().scaleEffect(0.9)
                        }
                        Text(viewModel.isRequestPending ? "申請已送出" : "申請加入")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.isRequestPending ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isRequestPending || isProcessingJoinRequest)
            }
            if let statusMessage = viewModel.requestStatusMessage {
                Text(statusMessage).font(.caption).foregroundColor(.secondary).padding(.top, 4)
            }
        }
    }
    
    private var roleQuickActions: some View {
        let canPublish = viewModel.canCreatePosts || viewModel.canCreateAnnouncements || viewModel.canCreateEvents || viewModel.canCreateTasks
        
        return Group {
            if viewModel.isMember && canPublish {
                VStack(alignment: .leading, spacing: 8) {
                    Text("快速操作")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if viewModel.canCreatePosts {
                                quickActionButton(title: "發貼文", systemImage: "square.and.pencil", tint: .blue) {
                                    startCreatePost(asAnnouncement: false)
                                }
                            }
                            
                            if viewModel.canCreateAnnouncements {
                                quickActionButton(title: "發公告", systemImage: "megaphone.fill", tint: .orange) {
                                    startCreatePost(asAnnouncement: true)
                                }
                            }
                            
                            if viewModel.canCreateEvents {
                                quickActionButton(title: "創建活動", systemImage: "calendar.badge.plus", tint: .purple) {
                                    openEventSignup()
                                }
                            }
                            
                            if viewModel.canCreateTasks {
                                quickActionButton(title: "指派任務", systemImage: "checklist", tint: .green) {
                                    openTaskBoard()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startGroupChat() {
        guard let organization = viewModel.organization else { return }
        isLoadingChat = true
        _Concurrency.Task {
            do {
                let roomId = try await ChatService.shared.getOrCreateOrganizationChatRoom(for: organization)
                await MainActor.run {
                    self.chatRoomId = roomId
                    self.isChatViewActive = true
                    self.isLoadingChat = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingChat = false
                }
                print("Error starting group chat: \(error.localizedDescription)")
                await MainActor.run {
                    chatErrorMessage = "啟動群組聊天失敗：\(error.localizedDescription)"
                    ToastManager.shared.showToast(message: chatErrorMessage ?? "啟動群組聊天失敗", type: .error)
                }
            }
        }
    }

    private func quickActionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.appSecondaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func startCreatePost(asAnnouncement: Bool) {
        guard viewModel.canCreatePosts || viewModel.canCreateAnnouncements else {
            ToastManager.shared.showToast(message: "您沒有權限發布內容", type: .error)
            return
        }
        createPostAsAnnouncement = asAnnouncement
        showingCreatePost = true
    }
    
    private func openTaskBoard() {
        guard viewModel.canCreateTasks else {
            ToastManager.shared.showToast(message: "您沒有權限指派任務", type: .error)
            return
        }
        
        if let app = viewModel.apps.first(where: { $0.templateKey == .taskBoard }) {
            taskBoardApp = app
            isNavigatingToTaskBoard = true
        } else {
            if viewModel.canManageApps {
                ToastManager.shared.showToast(message: "請先在「管理應用」啟用任務看板", type: .info)
                showingManageApps = true
            } else {
                ToastManager.shared.showToast(message: "請聯繫管理員啟用任務看板", type: .error)
            }
        }
    }
    
    private func openEventSignup() {
        guard viewModel.canCreateEvents else {
            ToastManager.shared.showToast(message: "您沒有權限創建活動", type: .error)
            return
        }
        
        if let app = viewModel.apps.first(where: { $0.templateKey == .eventSignup }) {
            eventSignupApp = app
            isNavigatingToEventSignup = true
        } else {
            if viewModel.canManageApps {
                ToastManager.shared.showToast(message: "請先在「管理應用」啟用活動報名", type: .info)
                showingManageApps = true
            } else {
                ToastManager.shared.showToast(message: "請聯繫管理員啟用活動報名", type: .error)
            }
        }
    }
    
    private func shareInvite() {
        guard !isGeneratingInvite else { return }
        isGeneratingInvite = true
        _Concurrency.Task {
            do {
                let invitation = try await viewModel.prepareShareableInvitation()
                await presentInviteShareSheet(invitation: invitation)
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast(message: "建立邀請碼失敗：\(error.localizedDescription)", type: .error)
                }
            }
            await MainActor.run { isGeneratingInvite = false }
        }
    }

    private var tabSelector: some View {
        Picker("視圖", selection: $selectedTab) {
            ForEach(DetailTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private func tabContent(for organization: Organization) -> some View {
        VStack(spacing: 16) {
            switch selectedTab {
            case .overview:
                OverviewTab(organization: organization, viewModel: viewModel)
            case .posts:
                OrganizationPostsTab(
                    viewModel: viewModel,
                    onCreatePost: viewModel.canCreatePosts ? { startCreatePost(asAnnouncement: false) } : nil,
                    onCreateAnnouncement: viewModel.canCreateAnnouncements ? { startCreatePost(asAnnouncement: true) } : nil
                )
            case .apps:
                OrganizationAppsTab(
                    viewModel: viewModel,
                    onOpenManageApps: viewModel.canManageApps ? { showingManageApps = true } : nil
                )
            }
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 150)
    }

    private func avatarPlaceholder(for organization: Organization) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(Text(String(organization.name.prefix(2)).uppercased()).font(.system(size: 28, weight: .bold)).foregroundColor(.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 3))
    }
    
    @MainActor
    private func presentInviteShareSheet(invitation: Invitation) {
        guard let org = viewModel.organization else { return }
        
        var lines: [String] = []
        lines.append("加入我的組織「\(org.name)」")
        lines.append("邀請碼：\(invitation.code)")
        
        if let expiration = invitation.expirationDate {
            lines.append("有效至：\(expiration.formatted(date: .numeric, time: .shortened))")
        } else {
            lines.append("有效期限：無限制")
        }
        
        if let maxUses = invitation.maxUses {
            let remaining = max(maxUses - invitation.currentUses, 0)
            lines.append("剩餘可用次數：\(remaining)")
        }
        
        lines.append("打開 Tired > 組織 > 輸入邀請碼加入")
        let inviteText = lines.joined(separator: "\n")
        
        let av = UIActivityViewController(activityItems: [inviteText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(av, animated: true, completion: nil)
        }
    }
}

// MARK: - Overview Tab
@available(iOS 17.0, *)
struct OverviewTab: View {
    let organization: Organization
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 統計數據
            if viewModel.isMember {
                VStack(alignment: .leading, spacing: 8) {
                    Text("統計數據").font(.system(size: 16, weight: .semibold))
                    
                    if viewModel.isLoadingStats {
                        ProgressView("載入中...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        HStack(spacing: 16) {
                            OrgStatCard(icon: "person.3.fill", value: "\(viewModel.memberCount)", label: "成員")
                            OrgStatCard(icon: "checklist", value: "\(viewModel.taskCount)", label: "任務")
                            OrgStatCard(icon: "calendar", value: "\(viewModel.eventCount)", label: "活動")
                        }
                    }
                }
                .padding()
                .background(Color.appSecondaryBackground)
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("關於").font(.system(size: 16, weight: .semibold))
                Text(organization.description ?? "暫無介紹")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                    .italic(organization.description == nil)
            }
            if viewModel.isMember, let membership = viewModel.currentMembership {
                VStack(alignment: .leading, spacing: 8) {
                    Text("我的身份").font(.system(size: 16, weight: .semibold))
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.blue)
                        
                        let roleNames = membership.roleIds.compactMap { roleId in
                            organization.roles.first { $0.id == roleId }?.name
                        }
                        
                        if roleNames.isEmpty {
                            Text("成員").font(.system(size: 14))
                        } else {
                            ForEach(roleNames, id: \.self) { name in
                                Text(name)
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }

                        if let title = membership.title {
                            Text("·").foregroundColor(.secondary)
                            Text(title).font(.system(size: 14)).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct OrgStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppDesignSystem.accentColor)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSecondaryBackground.opacity(0.5))
        .cornerRadius(8)
    }
}
// MARK: - Posts Tab
@available(iOS 17.0, *)
struct OrganizationPostsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    let onCreatePost: (() -> Void)?
    let onCreateAnnouncement: (() -> Void)?
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if !viewModel.posts.isEmpty {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("暫無貼文")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(viewModel.isMember ? "分享一則動態或公告，讓成員知道最新狀態" : "加入後即可查看組織貼文")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if viewModel.isMember {
                        HStack(spacing: 10) {
                            if let onCreateAnnouncement = onCreateAnnouncement {
                                Button {
                                    onCreateAnnouncement()
                                } label: {
                                    Text("發布公告")
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                            }
                            
                            if let onCreatePost = onCreatePost {
                                Button {
                                    onCreatePost()
                                } label: {
                                    Text("寫貼文")
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appSecondaryBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
            }
        }
        .padding()
    }
}

// MARK: - Apps Tab
@available(iOS 17.0, *)
struct OrganizationAppsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    let onOpenManageApps: (() -> Void)?
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if !viewModel.apps.isEmpty {
                ForEach(viewModel.apps) { app in
                    NavigationLink(destination: destinationView(for: app)) {
                        appCard(for: app)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("暫無應用")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(viewModel.canManageApps ? "啟用 TaskBoard、活動報名或資源清單，讓組織更好用" : "請聯繫管理員啟用所需的小應用")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if viewModel.canManageApps, let onOpenManageApps = onOpenManageApps {
                        Button {
                            onOpenManageApps()
                        } label: {
                            Text("管理小應用")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appSecondaryBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func destinationView(for app: OrgAppInstance) -> some View {
        switch app.templateKey {
        case .taskBoard:
            TaskBoardView(appInstance: app, organizationId: viewModel.organizationId)
        case .eventSignup:
            EventSignupView(appInstance: app, organizationId: viewModel.organizationId)
        case .resourceList:
            ResourceListView(appInstance: app, organizationId: viewModel.organizationId)
        case .courseSchedule:
            CourseScheduleView(appInstance: app)
        case .assignmentBoard:
            AssignmentBoardView(appInstance: app, organizationId: viewModel.organizationId)
        case .bulletinBoard:
            BulletinBoardView(appInstance: app)
        case .rollCall:
            RollCallView(appInstance: app)
        case .gradebook:
            GradebookView(appInstance: app)
        }
    }
    
    private func appCard(for app: OrgAppInstance) -> some View {
        HStack(spacing: 16) {
            Image(systemName: app.templateKey.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.blue) // Use a distinct color or app theme
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name ?? app.templateKey.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(app.templateKey.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}
