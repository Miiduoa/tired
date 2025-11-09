import SwiftUI

struct MeView: View {
    @EnvironmentObject var taskService: TaskService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.spacing2) {
                        // 個人資訊卡
                        ProfileCard()

                        // Streak & 成就
                        StreakCard()

                        // 本學期/最近完成
                        CompletedTasksCard()

                        // 設定
                        SettingsCard()
                    }
                    .padding(AppTheme.spacing2)
                }
            }
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileCard: View {
    @EnvironmentObject var taskService: TaskService

    var profile: UserProfile? {
        taskService.userProfile
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.primaryColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("用戶")
                            .font(AppTheme.headline)

                        if let termId = profile?.currentTermId {
                            if termId == "personal-default" {
                                Text("個人模式")
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            } else {
                                Text("學期：\(termId)")
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("平日可用時間")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(profile?.weekdayCapacityMin ?? 0) 分鐘")
                            .font(AppTheme.body)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("週末可用時間")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(profile?.weekendCapacityMin ?? 0) 分鐘")
                            .font(AppTheme.body)
                    }
                }
            }
        }
    }
}

struct StreakCard: View {
    @EnvironmentObject var taskService: TaskService

    var streak: Int {
        taskService.userProfile?.streakDays ?? 0
    }

    var totalCompleted: Int {
        taskService.userProfile?.totalCompletedTasks ?? 0
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                Text("成就")
                    .font(AppTheme.headline)

                HStack(spacing: AppTheme.spacing3) {
                    VStack {
                        Text("🔥")
                            .font(.system(size: 40))
                        Text("\(streak) 天")
                            .font(AppTheme.subheadline)
                        Text("連續完成")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    VStack {
                        Text("✅")
                            .font(.system(size: 40))
                        Text("\(totalCompleted)")
                            .font(AppTheme.subheadline)
                        Text("總完成數")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    VStack {
                        Text("⭐️")
                            .font(.system(size: 40))
                        Text("0")
                            .font(AppTheme.subheadline)
                        Text("成就徽章")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

struct CompletedTasksCard: View {
    @EnvironmentObject var taskService: TaskService

    var completedTasks: [Task] {
        let currentTermId = taskService.userProfile?.currentTermId

        return taskService.tasks.filter { task in
            task.state == .done &&
            task.deletedAt == nil &&
            (task.category != .school ||
             task.termId == currentTermId ||
             task.isCrossTermImportant)
        }
        .sorted { $0.doneAt ?? Date() > $1.doneAt ?? Date() }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                HStack {
                    Text("最近完成")
                        .font(AppTheme.headline)
                    Spacer()
                    Text("\(completedTasks.count)")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                if completedTasks.isEmpty {
                    Text("還沒有完成的任務")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.vertical, AppTheme.spacing2)
                } else {
                    ForEach(completedTasks) { task in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.successColor)
                            Text(task.title)
                                .font(AppTheme.body)
                                .lineLimit(1)
                            Spacer()
                            if let doneAt = task.doneAt {
                                Text(DateUtils.formatDate(doneAt, style: .short))
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                }

                Button(action: {
                    // TODO: 匯出經歷
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("匯出本學期經歷")
                    }
                    .font(AppTheme.body)
                    .frame(maxWidth: .infinity)
                }
                .secondaryButton()
            }
        }
    }
}

struct SettingsCard: View {
    @EnvironmentObject var taskService: TaskService

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                Text("設定")
                    .font(AppTheme.headline)

                NavigationLink(destination: Text("容量設定")) {
                    SettingsRow(icon: "clock", title: "容量設定")
                }

                NavigationLink(destination: Text("專注模式")) {
                    SettingsRow(icon: "timer", title: "專注模式")
                }

                NavigationLink(destination: Text("學期管理")) {
                    SettingsRow(icon: "calendar", title: "學期管理")
                }

                NavigationLink(destination: Text("通知設定")) {
                    SettingsRow(icon: "bell", title: "通知設定")
                }

                Button(action: {
                    // 登出
                    // TODO: 實現登出邏輯
                }) {
                    SettingsRow(icon: "arrow.right.square", title: "登出", color: AppTheme.errorColor)
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var color: Color = AppTheme.primaryColor

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(AppTheme.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
