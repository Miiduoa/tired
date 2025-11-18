import SwiftUI

@available(iOS 17.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 任务中枢
            TasksView()
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }
                .tag(0)

            // 动态墙（占位）
            FeedView()
                .tabItem {
                    Label("动态", systemImage: "newspaper")
                }
                .tag(1)

            // 组织（占位）
            OrganizationsView()
                .tabItem {
                    Label("身份", systemImage: "building.2")
                }
                .tag(2)

            // 个人（占位）
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
}

// Note: Views are now in separate files for better organization
// - FeedView: Views/Feed/FeedView.swift
// - OrganizationsView: Views/Organizations/OrganizationsView.swift
// - ProfileView: Views/Profile/ProfileView.swift
