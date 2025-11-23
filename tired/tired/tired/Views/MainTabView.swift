import SwiftUI

@available(iOS 17.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 任務中樞
            TasksView()
                .tabItem {
                    Label("任務", systemImage: "checklist")
                }
                .tag(0)

            // 日曆視圖
            CalendarView()
                .tabItem {
                    Label("日曆", systemImage: "calendar")
                }
                .tag(1)

            // 動態墻 - 使用 TiredApp/Views/Feed/FeedView.swift
            FeedView()
                .tabItem {
                    Label("動態", systemImage: "newspaper")
                }
                .tag(2)

            // 組織管理 - 使用 TiredApp/Views/Organizations/OrganizationsView.swift
            OrganizationsView()
                .tabItem {
                    Label("身份", systemImage: "building.2")
                }
                .tag(3)

            // 個人資料 - 使用 TiredApp/Views/Profile/ProfileView.swift
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(4)
        }
    }
}
