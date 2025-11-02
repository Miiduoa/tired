import SwiftUI

// 輕量殼層：直接承載新版 MainAppView，確保登入後呈現現代化 UI
struct AppShellView: View {
    var body: some View {
        MainAppView()
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

// 舊版 OrganizationShellView/GroupsTab 不再使用，統一走 MainAppView 的現代化路由
