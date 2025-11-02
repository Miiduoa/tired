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
                    OrganizationShellView(session: session, membership: membership)
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
    
    enum OrgTab: Hashable { case home, inbox, messages, me }
    @State private var tab: OrgTab = .home
    
    var body: some View {
        TabView(selection: $tab) {
            OrgHomeView(session: session, membership: membership)
                .tabItem { Label("首頁", systemImage: "house.fill") }
                .tag(OrgTab.home)
            InboxView(membership: membership)
                .tabItem { Label("收件匣", systemImage: "tray.fill") }
                .tag(OrgTab.inbox)
            ChatListView(session: session)
                .tabItem { Label("訊息", systemImage: "message.fill") }
                .tag(OrgTab.messages)
            NavigationStack { AccountView() }
                .environmentObject(authService)
                .tabItem { Label("我", systemImage: "person.crop.circle") }
                .tag(OrgTab.me)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea(.all))
    }
}


