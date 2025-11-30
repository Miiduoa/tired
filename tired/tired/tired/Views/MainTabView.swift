import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var networkMonitor: NetworkMonitor

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(Color.appSecondaryBackground.opacity(0.9))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppDesignSystem.accentColor)
        appearance.inlineLayoutAppearance.selected.iconColor = UIColor(AppDesignSystem.accentColor)
        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(AppDesignSystem.accentColor)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LayeredBackground()
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // 1. Home / Dashboard (Focus)
                HomeDashboardView()
                    .tabItem {
                        Label("首頁", systemImage: "house.fill")
                    }
                    .tag(0)

                // 2. Tasks (Work)
                TasksView()
                    .tabItem {
                        Label("任務", systemImage: "checklist")
                    }
                    .tag(1)

                // 3. Organizations (Groups)
                OrganizationsView()
                    .tabItem {
                        Label("組織", systemImage: "person.3.fill")
                    }
                    .tag(2)

                // 4. Chat (Communication)
                ChatListView()
                    .tabItem {
                        Label("訊息", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(3)
                
                // 5. Profile
                ProfileView()
                    .tabItem {
                        Label("我的", systemImage: "person.circle")
                    }
                    .tag(4)
            }
            .background(Color.clear)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Material.thin, for: .tabBar)
            .tint(AppDesignSystem.accentColor)

            // 使用新的離線橫幅視圖
            VStack {
                OfflineBannerView()
                    .environmentObject(networkMonitor)
                Spacer()
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTaskDetail)) { _ in
            selectedTab = 1 // Switch to Tasks tab
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTasksTab)) { _ in
            selectedTab = 1 // Switch to Tasks tab
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToEventDetail)) { _ in
            selectedTab = 0 // Switch to Home tab where events might be highlighted, or keep current context
            // In a real scenario, this might navigate to a specific Calendar tab or deep link.
        }
    }
}
