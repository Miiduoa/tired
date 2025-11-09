import SwiftUI

struct ThisWeekView: View {
    @EnvironmentObject var taskService: TaskService

    var weekStart: Date {
        AppSession.shared.weekStart()
    }

    var weekTasks: [Date: [Task]] {
        taskService.getThisWeekTasks()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.spacing2) {
                        // 週壓力總覽
                        WeekLoadSummaryCard()

                        // 每日任務
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let day = DateUtils.addDays(weekStart, dayIndex)
                            DayCard(date: day, tasks: weekTasks[day] ?? [])
                        }
                    }
                    .padding(AppTheme.spacing2)
                }
            }
            .navigationTitle("本週")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct WeekLoadSummaryCard: View {
    @EnvironmentObject var taskService: TaskService

    var weekStart: Date {
        AppSession.shared.weekStart()
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                HStack {
                    Text("本週壓力總覽")
                        .font(AppTheme.headline)
                    Spacer()
                    Text(moodEmoji)
                        .font(.system(size: 30))
                }

                // 負荷圖
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let day = DateUtils.addDays(weekStart, dayIndex)
                        let ratio = taskService.loadRatioForDay(day)

                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(colorForRatio(ratio))
                                .frame(height: heightForRatio(ratio))

                            Text(weekdayLabel(dayIndex))
                                .font(AppTheme.footnote)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                Text(suggestion)
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var moodEmoji: String {
        let ratios = (0..<7).map { dayIndex in
            taskService.loadRatioForDay(DateUtils.addDays(weekStart, dayIndex))
        }
        let avg = ratios.reduce(0.0, +) / Double(ratios.count)
        let hardDays = ratios.filter { $0 > 1.3 }.count

        if avg < 0.9 && hardDays == 0 {
            return "🙂"
        } else if avg <= 1.4 && hardDays <= 2 {
            return "😐"
        } else {
            return "😵"
        }
    }

    private var suggestion: String {
        let ratios = (0..<7).map { dayIndex in
            taskService.loadRatioForDay(DateUtils.addDays(weekStart, dayIndex))
        }
        let avg = ratios.reduce(0.0, +) / Double(ratios.count)
        let hardDays = ratios.filter { $0 > 1.3 }.count

        if avg < 0.9 && hardDays == 0 {
            return "這週還很鬆，可以從 Backlog 挑一兩顆重要的進來。"
        } else if avg <= 1.4 && hardDays <= 2 {
            return "這週看起來在可控範圍內，維持這個節奏就好。"
        } else {
            return "這週有好幾天可能太硬，試試把一些任務延到下週。"
        }
    }

    private func colorForRatio(_ ratio: Double) -> Color {
        if ratio < 0.7 {
            return AppTheme.successColor
        } else if ratio < 1.0 {
            return AppTheme.primaryColor
        } else if ratio < 1.3 {
            return AppTheme.warningColor
        } else {
            return AppTheme.errorColor
        }
    }

    private func heightForRatio(_ ratio: Double) -> CGFloat {
        let normalized = min(ratio, 2.0) / 2.0
        return CGFloat(normalized) * 80 + 20
    }

    private func weekdayLabel(_ index: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][index]
    }
}

struct DayCard: View {
    let date: Date
    let tasks: [Task]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                HStack {
                    Text(DateUtils.relativeDayDescription(date))
                        .font(AppTheme.subheadline)
                    Spacer()
                    Text("\(tasks.count) 個任務")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                if tasks.isEmpty {
                    Text("還沒有安排任務")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    ForEach(tasks.prefix(3)) { task in
                        HStack {
                            Circle()
                                .fill(task.priority.color)
                                .frame(width: 8, height: 8)
                            Text(task.title)
                                .font(AppTheme.body)
                                .lineLimit(1)
                        }
                    }

                    if tasks.count > 3 {
                        Text("還有 \(tasks.count - 3) 個...")
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}
