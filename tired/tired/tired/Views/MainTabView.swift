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

// MARK: - Feed View (Placeholder)

@available(iOS 17.0, *)
struct FeedView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<5) { _ in
                        PostCardPlaceholder()
                    }
                }
                .padding()
            }
            .navigationTitle("动态墙")
        }
    }
}

@available(iOS 17.0, *)
struct PostCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("组织名称")
                        .font(.system(size: 14, weight: .semibold))
                    Text("2小时前")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text("这里是贴文内容占位符。之后会显示组织和个人的动态更新。")
                .font(.system(size: 14))
                .foregroundColor(.primary)

            HStack(spacing: 24) {
                Label("12", systemImage: "heart")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Label("5", systemImage: "bubble.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Organizations View (Placeholder)

@available(iOS 17.0, *)
struct OrganizationsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    InfoCard(
                        title: "多身份管理",
                        description: "在这里管理你的所有身份：学校、工作、社团等。每个身份都有独立的任务和活动。"
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("我的身份")
                            .font(.headline)

                        OrganizationCardPlaceholder(
                            name: "静宜大学资管系",
                            type: "学校",
                            role: "学生"
                        )

                        OrganizationCardPlaceholder(
                            name: "OO饮料店",
                            type: "工作",
                            role: "员工"
                        )

                        OrganizationCardPlaceholder(
                            name: "吉他社",
                            type: "社团",
                            role: "成员"
                        )
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("我的身份")
        }
    }
}

@available(iOS 17.0, *)
struct InfoCard: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
struct OrganizationCardPlaceholder: View {
    let name: String
    let type: String
    let role: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: typeIcon)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                HStack(spacing: 8) {
                    Text(type)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(role)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }

    private var typeIcon: String {
        switch type {
        case "学校": return "building.columns"
        case "工作": return "briefcase"
        case "社团": return "music.note"
        default: return "folder"
        }
    }
}

// MARK: - Profile View (Placeholder)

@available(iOS 17.0, *)
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationView {
            List {
                Section {
                    if let profile = authService.userProfile {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(profile.name.prefix(1)))
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.blue)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(profile.email)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("设置") {
                    NavigationLink {
                        Text("每周时间容量设置")
                    } label: {
                        Label("时间管理", systemImage: "clock")
                    }

                    NavigationLink {
                        Text("通知设置")
                    } label: {
                        Label("通知", systemImage: "bell")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        try? authService.signOut()
                    } label: {
                        Text("登出")
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}
