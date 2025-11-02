import SwiftUI

struct AppShellView: View {
    @StateObject private var sessionStore = AppSessionStore()
    @StateObject private var moduleManager = TenantModuleManager()
    
    var body: some View {
        Group {
            switch sessionStore.state {
            case .loading:
                ProgressView("載入中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                AuthView().environmentObject(sessionStore.authService)
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 48)).foregroundStyle(.orange)
                    Text(message).font(.headline).multilineTextAlignment(.center)
                    Button("重新整理") { Task { await sessionStore.refreshMemberships() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready(let session):
                if let membership = session.activeMembership ?? session.allMemberships.first {
                    OrganizationShellView(
                        session: session,
                        membership: membership,
                        onSwitchTenant: { id in sessionStore.switchActiveMembership(to: id) }
                    )
                        .environmentObject(sessionStore.authService)
                } else {
                    PersonalShellView(session: session)
                        .environmentObject(sessionStore.authService)
                }
            }
        }
        .task {
            if case .loading = sessionStore.state {
                await sessionStore.refreshMemberships()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea(.all))
    }
}

private struct OrganizationShellView: View {
    let session: AppSession
    let membership: TenantMembership
    @EnvironmentObject private var authService: AuthService
    let onSwitchTenant: (String) -> Void
    
    enum OrgTab: Hashable { case home, groups, messages, me }
    @State private var tab: OrgTab = .home
    @State private var inboxCount: Int = 0
    @State private var unreadMessages: Int = 0
    
    var body: some View {
        TabView(selection: $tab) {
            GlobalFeedView(session: session, membership: membership, personalTimelineStore: nil, feedService: GlobalFeedService())
                .tabItem { Label("首頁", systemImage: "house.fill") }
                .tag(OrgTab.home)
            GroupsTab(session: session, active: membership, onSwitch: onSwitchTenant)
                .tabItem { Label("組織", systemImage: "building.2") }
                .badge(inboxCount)
                .tag(OrgTab.groups)
            ChatListView(session: session)
                .tabItem { Label("訊息", systemImage: "message.fill") }
                .badge(unreadMessages)
                .tag(OrgTab.messages)
            NavigationStack { AccountView() }
                .environmentObject(authService)
                .tabItem { Label("我", systemImage: "person.crop.circle") }
                .tag(OrgTab.me)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea(.all))
        .task(id: membership.id) { await reloadBadges() }
        .onChange(of: tab) { _ in Task { await reloadBadges() } }
    }
    
    @MainActor
    private func reloadBadges() async {
        // Inbox 待辦
        let items = await TenantFeatureService().inboxItems(for: membership)
        inboxCount = items.count
        // 訊息未讀（採樣會話）
        let chat: ChatServiceProtocol = ChatServiceRouter.make()
        let convos = await chat.conversations(for: session.user.id)
        var total = 0
        for c in convos { total += await chat.unreadCount(conversationId: c.id, userId: session.user.id, sampleLimit: 50) }
        unreadMessages = total
    }
}

private struct GroupsTab: View {
    let session: AppSession
    let active: TenantMembership
    let onSwitch: (String) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section("我的組織") {
                    ForEach(session.allMemberships, id: \.id) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.tenant.name).font(.subheadline.weight(.semibold))
                                Text(m.role.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if m.id == active.id { Image(systemName: "checkmark").foregroundStyle(Color.tint) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onSwitch(m.id) }
                    }
                }
            }
            .navigationTitle("組織")
            .background(Color.bg.ignoresSafeArea())
        }
    }
}
