import SwiftUI

@available(iOS 17.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // No direct init customization needed for UITabBarAppearance due to SwiftUI modifiers
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TasksView()
                .tabItem {
                    Label("任務", systemImage: "checklist")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label("日曆", systemImage: "calendar")
                }
                .tag(1)

            FeedView()
                .tabItem {
                    Label("動態", systemImage: "newspaper")
                }
                .tag(2)

            OrganizationsView()
                .tabItem {
                    Label("身份", systemImage: "building.2")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(4)
        }
        .background(Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)) // Apply primary background
        .toolbarBackground(.visible, for: .tabBar) // Make tab bar background visible
        .toolbarBackground(Material.thin, for: .tabBar) // Apply thin material effect
        .tint(AppDesignSystem.accentColor) // Tint selected tab item
    }
}