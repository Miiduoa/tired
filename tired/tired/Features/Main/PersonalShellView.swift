import SwiftUI

struct PersonalShellView: View {
    let session: AppSession
    @StateObject private var timelineStore: PersonalTimelineStore
    
    init(session: AppSession) {
        self.session = session
        _timelineStore = StateObject(wrappedValue: PersonalTimelineStore(user: session.user))
    }
    
    enum Tab: Hashable { case home, explore, messages, me }
    @State private var tab: Tab = .home
    private let feedService: GlobalFeedServiceProtocol = GlobalFeedService()
    
    var body: some View {
        TabView(selection: $tab) {
            // Home：個人動態（沿用 GlobalFeedView 個人模式）
            GlobalFeedView(session: session, membership: nil, personalTimelineStore: timelineStore, feedService: feedService)
                .tabItem { Label("首頁", systemImage: "person.crop.circle") }
                .tag(Tab.home)
            // Explore：機會/探索（暫以 GlobalFeedView 取代，後續接 PersonalExploreView 2.0）
            ExploreView(session: session)
                .tabItem { Label("探索", systemImage: "globe") }
                .tag(Tab.explore)
            // Messages：聊天
            ChatListView(session: session)
                .tabItem { Label("訊息", systemImage: "message.fill") }
                .tag(Tab.messages)
            // Me：個人
            NavigationStack { ProfileView() }
                .tabItem { Label("我", systemImage: "person.fill") }
                .tag(Tab.me)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea(.all))
    }
}

