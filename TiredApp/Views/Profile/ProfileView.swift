import SwiftUI

@available(iOS 17.0, *)
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSettings = false
    @State private var showingEditProfile = false

    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    if let profile = authService.userProfile {
                        HStack(spacing: 16) {
                            // Avatar
                            if let avatarUrl = profile.avatarUrl {
                                AsyncImage(url: URL(string: avatarUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder(name: profile.name)
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder(name: profile.name)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(profile.name)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(profile.email)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Statistics Section
                Section {
                    NavigationLink(destination: MyTasksStatsView()) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("任務統計")
                        }
                    }

                    NavigationLink(destination: MyOrganizationsListView()) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("我的組織")
                        }
                    }

                    NavigationLink(destination: MyEventsView()) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("我的活動")
                        }
                    }
                } header: {
                    Text("概覽")
                }

                // Settings Section
                Section {
                    NavigationLink(destination: TimeManagementSettingsView()) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("時間管理")
                        }
                    }

                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("通知設置")
                        }
                    }

                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            Text("外觀")
                        }
                    }
                } header: {
                    Text("設置")
                }

                // About Section
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("關於 Tired")
                        }
                    }

                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("幫助與支持")
                        }
                    }
                } header: {
                    Text("其他")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        do {
                            try authService.signOut()
                        } catch {
                            print("❌ Error signing out: \(error)")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 24)
                            Text("登出")
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }

    private func avatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 70, height: 70)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - My Tasks Stats View

@available(iOS 17.0, *)
struct MyTasksStatsView: View {
    var body: some View {
        List {
            Section("本週統計") {
                HStack {
                    Text("已完成任務")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("待完成任務")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("總預估時長")
                    Spacer()
                    Text("0 小時")
                        .foregroundColor(.secondary)
                }
            }

            Section("分類統計") {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("學校")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("工作")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                    Text("社團")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("生活")
                    Spacer()
                    Text("0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("任務統計")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My Organizations List View

@available(iOS 17.0, *)
struct MyOrganizationsListView: View {
    var body: some View {
        Text("我的組織列表")
            .navigationTitle("我的組織")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My Events View

@available(iOS 17.0, *)
struct MyEventsView: View {
    var body: some View {
        Text("我報名的活動")
            .navigationTitle("我的活動")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Time Management Settings View

@available(iOS 17.0, *)
struct TimeManagementSettingsView: View {
    @State private var weeklyCapacityHours: Double = 12.0
    @State private var dailyCapacityHours: Double = 8.0

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每週時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", weeklyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $weeklyCapacityHours, in: 1...40, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", dailyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $dailyCapacityHours, in: 1...16, step: 1)
                }
            } header: {
                Text("時間容量")
            } footer: {
                Text("用於自動排程時計算每週和每日的任務量")
            }
        }
        .navigationTitle("時間管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notification Settings View

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @State private var enableNotifications = true
    @State private var taskReminders = true
    @State private var eventReminders = true
    @State private var organizationUpdates = true

    var body: some View {
        Form {
            Section {
                Toggle("啟用通知", isOn: $enableNotifications)
            }

            Section {
                Toggle("任務提醒", isOn: $taskReminders)
                Toggle("活動提醒", isOn: $eventReminders)
                Toggle("組織動態", isOn: $organizationUpdates)
            } header: {
                Text("通知類型")
            }
            .disabled(!enableNotifications)
        }
        .navigationTitle("通知設置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Settings View

@available(iOS 17.0, *)
struct AppearanceSettingsView: View {
    @State private var selectedTheme = "auto"

    var body: some View {
        Form {
            Section {
                Picker("主題", selection: $selectedTheme) {
                    Text("跟隨系統").tag("auto")
                    Text("淺色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("外觀主題")
            }
        }
        .navigationTitle("外觀")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About View

@available(iOS 17.0, *)
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("構建號")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Text("Tired 是一個專為現代斜槓青年設計的多身份任務管理應用。支持學校、工作、社團等多種身份的任務統籌與智能排程。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } header: {
                Text("關於應用")
            }

            Section {
                Link("隱私政策", destination: URL(string: "https://example.com/privacy")!)
                Link("服務條款", destination: URL(string: "https://example.com/terms")!)
                Link("開源許可", destination: URL(string: "https://example.com/licenses")!)
            }
        }
        .navigationTitle("關於 Tired")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help View

@available(iOS 17.0, *)
struct HelpView: View {
    var body: some View {
        List {
            Section("常見問題") {
                NavigationLink("如何創建組織？") {
                    Text("幫助內容")
                }

                NavigationLink("如何使用自動排程？") {
                    Text("幫助內容")
                }

                NavigationLink("如何報名活動？") {
                    Text("幫助內容")
                }
            }

            Section("聯繫我們") {
                Link("發送郵件", destination: URL(string: "mailto:support@tired.app")!)
                Link("反饋問題", destination: URL(string: "https://github.com/tired/issues")!)
            }
        }
        .navigationTitle("幫助與支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}
