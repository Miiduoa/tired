import SwiftUI

struct MainAppView: View {
    @StateObject private var sessionStore = AppSessionStore()
    @StateObject private var moduleManager = TenantModuleManager()
    @State private var selectedModule: AppModule = .home
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        content
            .task {
                if case .loading = sessionStore.state {
                    await sessionStore.refreshMemberships()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        if case .ready(let session) = sessionStore.state {
                            await OutboxService.shared.flush(session: session)
                        } else {
                            await OutboxService.shared.flush()
                        }
                        VideoThumbnailCache.shared.cleanup()
                    }
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        switch sessionStore.state {
        case .loading:
            ProgressView("載入中…")
                .progressViewStyle(.circular)
        case .signedOut:
            AuthView().environmentObject(sessionStore.authService)
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("重新整理") {
                    Task { await sessionStore.refreshMemberships() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .ready(let session):
            if let activeMembership = session.activeMembership {
                OrganizationTabView(
                    session: session,
                    activeMembership: activeMembership,
                    moduleManager: moduleManager,
                    selectedModule: $selectedModule,
                    onSwitchTenant: { membershipId in
                        sessionStore.switchActiveMembership(to: membershipId)
                    },
                    onRefresh: {
                        Task { await sessionStore.refreshMemberships() }
                    }
                )
                .environmentObject(sessionStore.authService)
            } else {
                PersonalMainView(session: session)
                    .environmentObject(sessionStore.authService)
            }
        }
    }
}

private struct OrganizationTabView: View {
    let session: AppSession
    let activeMembership: TenantMembership
    @ObservedObject var moduleManager: TenantModuleManager
    @Binding var selectedModule: AppModule
    let onSwitchTenant: (String) -> Void
    let onRefresh: () -> Void
    @EnvironmentObject private var authService: AuthService
    
    private var modules: [AppModule] {
        moduleManager.availableModules(for: activeMembership)
    }
    
    var body: some View {
        TabView(selection: $selectedModule) {
            ForEach(modules, id: \.self) { module in
                tabContent(for: module)
                    .tag(module)
                    .tabItem {
                        let meta = moduleManager.metadata(for: module, membership: activeMembership)
                        Label(meta.title, systemImage: meta.systemImage)
                    }
            }
        }
        .task {
            if !modules.contains(selectedModule) {
                selectedModule = .home
            }
        }
    }
    
    @ViewBuilder
    private func tabContent(for module: AppModule) -> some View {
        switch module {
        case .home:
            HomeView(
                session: session,
                membership: activeMembership,
                moduleManager: moduleManager,
                modules: modules,
                selectedModule: $selectedModule,
                onSwitchTenant: onSwitchTenant,
                onRefreshTenant: onRefresh
            )
        case .broadcast:
            NavigationStack { BroadcastListView(membership: activeMembership) }
        case .inbox:
            NavigationStack { InboxView(membership: activeMembership) }
        case .attendance:
            NavigationStack { AttendanceView(membership: activeMembership) }
        case .clock:
            NavigationStack { ClockView(membership: activeMembership) }
        case .esg:
            NavigationStack { ESGOverviewView(membership: activeMembership) }
        case .activities:
            NavigationStack { ActivityBoardView(membership: activeMembership) }
        case .insights:
            NavigationStack { InsightsView(membership: activeMembership) }
        case .feed:
            GlobalFeedView(session: session, membership: activeMembership, personalTimelineStore: nil, feedService: GlobalFeedService())
        case .chat:
            ChatListView(session: session)
        case .friends:
            FriendsView(session: session)
        case .profile:
            NavigationStack { AccountView() }
                .environmentObject(authService)
        }
    }
}

private struct HomeView: View {
    let session: AppSession
    let membership: TenantMembership
    @ObservedObject var moduleManager: TenantModuleManager
    let modules: [AppModule]
    @Binding var selectedModule: AppModule
    let onSwitchTenant: (String) -> Void
    let onRefreshTenant: () -> Void
    
    @State private var quickActions: [TenantModuleEntryAction] = []
    @State private var attendanceSnapshot: AttendanceSnapshot?
    @State private var broadcasts: [BroadcastListItem] = []
    @State private var clockRecords: [ClockRecordItem] = []
    @State private var activities: [ActivityListItem] = []
    
    private let featureService = TenantFeatureService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tenantHeader
                    quickActionsSection
                    statsSection
                    recentActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("首頁")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(session.allMemberships, id: \.id) { candidate in
                            Button {
                                onSwitchTenant(candidate.id)
                            } label: {
                                Label(candidate.tenant.name, systemImage: candidate.id == membership.id ? "checkmark" : "building.2")
                            }
                        }
                    } label: {
                        Label(membership.tenant.name, systemImage: "building.2.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onRefreshTenant()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task(id: membership.id) {
                await refreshContent()
            }
        }
    }
    
    private var tenantHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(membership.tenant.name)
                .font(.title2.weight(.semibold))
            HStack(spacing: 8) {
                Label(membership.tenant.type.displayName, systemImage: "building.2")
                Label(membership.role.displayName, systemImage: "person.fill.badge.plus")
                Label(membership.capabilityPack.name, systemImage: "puzzlepiece.extension")
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("快速操作")
                    .font(.headline)
                Spacer()
                if !modules.filter({ $0 != .home }).isEmpty {
                    Button("管理模組") {
                        selectedModule = .profile
                    }
                    .font(.footnote)
                }
            }
            if RolePermissions.canManageMembers(membership.role) {
                NavigationLink {
                    MemberManagementView(membership: membership)
                } label: {
                    HStack {
                        Label("成員管理", systemImage: "person.3.fill")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            if quickActions.isEmpty {
                Text("尚未配置模組或權限不足")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(quickActions) { action in
                        QuickActionCard(action: action)
                    }
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本日觀測")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let snapshot = attendanceSnapshot, snapshot.stats.total > 0, membership.hasAccess(to: .attendance) {
                    let rate = Double(snapshot.stats.attended) / Double(snapshot.stats.total)
                    HomeStatCard(
                        title: "今日到課率",
                        value: String(format: "%.0f%%", rate * 100),
                        subtitle: "已簽到 \(snapshot.stats.attended)/\(snapshot.stats.total)",
                        icon: "person.3.fill",
                        color: .green
                    )
                }
                if membership.hasAccess(to: .broadcast) {
                    let pending = broadcasts.filter { $0.requiresAck && !AckStore.shared.isAcked($0.id) }.count
                    HomeStatCard(
                        title: "需回條公告",
                        value: "\(pending)",
                        subtitle: pending > 0 ? "待確認" : "全部完成",
                        icon: "megaphone.fill",
                        color: .purple
                    )
                }
                if membership.hasAccess(to: .clock) {
                    let exceptions = clockRecords.filter { $0.status == .exception }.count
                    HomeStatCard(
                        title: "打卡異常",
                        value: "\(exceptions)",
                        subtitle: exceptions > 0 ? "待覆核" : "全部正常",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )
                }
                if membership.hasAccess(to: .esg) {
                    HomeStatCard(
                        title: "碳排挑戰",
                        value: membership.metadata["esg.progress"] ?? "82%",
                        subtitle: "目標完成度",
                        icon: "leaf.fill",
                        color: .mint
                    )
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近活動")
                    .font(.headline)
                Spacer()
                Button("查看全部") {
                    selectedModule = .inbox
                }
                .font(.footnote)
            }
            if activities.isEmpty {
                Text("目前尚無活動記錄")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activities.sorted { $0.timestamp > $1.timestamp }.prefix(5)) { activity in
                    HomeActivityRow(activity: activity)
                }
            }
        }
    }
    
    private func refreshContent() async {
        async let quick = moduleManager.quickActions(for: modules, session: session) { module in
            Task { @MainActor in
                selectedModule = module
            }
        }
        async let broadcastsTask = featureService.broadcasts(for: membership)
        async let inboxTask = featureService.inboxItems(for: membership)
        async let attendanceTask = featureService.attendanceSnapshot(for: membership)
        async let activityTask = featureService.activities(for: membership)
        async let clockTask = featureService.clockRecords(for: membership)
        
        let (qa, bc, _, attendance, activity, clock) = await (
            quick,
            broadcastsTask,
            inboxTask,
            attendanceTask,
            activityTask,
            clockTask
        )
        await MainActor.run {
            quickActions = qa
            broadcasts = bc
            attendanceSnapshot = attendance
            activities = activity
            clockRecords = clock
        }
    }
}

private struct QuickActionCard: View {
    let action: TenantModuleEntryAction
    
    var body: some View {
        Button(action: action.action) {
            VStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundStyle(action.color)
                Text(action.title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                if let badge = action.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(action.color.opacity(0.15), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HomeActivityRow: View {
    let activity: ActivityListItem
    
    private var icon: String {
        switch activity.kind {
        case .broadcast: return "megaphone.fill"
        case .rollcall: return "qrcode.viewfinder"
        case .clock: return "mappin.and.ellipse"
        case .esg: return "leaf.fill"
        }
    }
    
    private var color: Color {
        switch activity.kind {
        case .broadcast: return .purple
        case .rollcall: return .orange
        case .clock: return .green
        case .esg: return .mint
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline.weight(.medium))
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(activity.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct FeedPlaceholderView: View {
    let title: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }
}
