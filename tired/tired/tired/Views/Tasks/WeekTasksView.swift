import SwiftUI

@available(iOS 17.0, *)
struct WeekTasksView: View {
    @ObservedObject var viewModel: TasksViewModel
    @State private var processingTaskIds: Set<String> = []
    @State private var showingAddTask = false

    var body: some View {
        let stats = viewModel.weeklyStatistics()
        let tasks = viewModel.filteredTasks(viewModel.weekTasks)
        let totalTasksThisWeek = tasks.count
        let totalMinutesPlanned = stats.reduce(0) { $0 + $1.duration }

        VStack(spacing: AppDesignSystem.paddingMedium) {
            // Weekly capacity indicator
            WeeklyCapacityView(stats: stats, dailyCapacity: viewModel.userProfile?.dailyCapacityMinutes ?? 120)

            // 如果本週沒有任務，顯示空狀態
            if totalTasksThisWeek == 0 {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "本週還沒有安排",
                    message: "使用智能排程來規劃本週的任務，或手動添加任務。",
                    actionTitle: "智能排程",
                    action: { 
                        NotificationCenter.default.post(name: .showAutoplan, object: nil)
                    },
                    secondaryActionTitle: "手動新增",
                    secondaryAction: { showingAddTask = true }
                )
                .sheet(isPresented: $showingAddTask) {
                    AddTaskView(viewModel: viewModel)
                }
            } else {
                // 週摘要卡片
                WeekSummaryCard(
                    totalTasks: totalTasksThisWeek,
                    totalMinutes: totalMinutesPlanned,
                    completedTasks: tasks.filter { $0.isDone }.count
                )
                
                // Daily sections
                ForEach(stats, id: \.day) { stat in
                    let dayTasks = tasks.filter { task in
                        let calendar = Calendar.current
                        if let planned = task.plannedDate,
                           calendar.isDate(planned, equalTo: stat.day, toGranularity: .day) {
                            return true
                        }
                        // 未排程但有截止時間，放入截止日，避免週視圖漏掉
                        if task.plannedDate == nil,
                           let deadline = task.deadlineAt,
                           calendar.isDate(deadline, equalTo: stat.day, toGranularity: .day) {
                            return true
                        }
                        return false
                    }

                    DayTasksCard(
                        date: stat.day,
                        duration: stat.duration,
                        tasks: dayTasks,
                        onToggle: { task in await toggleTask(task) },
                        viewModel: viewModel
                    )
                }
            }
        }
    }

    private func toggleTask(_ task: Task) async -> Bool {
        guard let id = task.id else { return false }
        await MainActor.run {
            guard !processingTaskIds.contains(id) else { return }
            processingTaskIds.insert(id)
        }

        let success = await viewModel.toggleTaskDoneAsync(task: task)

        try? await _Concurrency.Task.sleep(nanoseconds: 150_000_000)

        _ = await MainActor.run {
            processingTaskIds.remove(id)
        }

        return success
    }
}

// MARK: - 週摘要卡片
@available(iOS 17.0, *)
struct WeekSummaryCard: View {
    let totalTasks: Int
    let totalMinutes: Int
    let completedTasks: Int
    
    private var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    private var formattedTime: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)小時\(minutes)分"
        } else if hours > 0 {
            return "\(hours)小時"
        } else {
            return "\(minutes)分鐘"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 完成率圓環
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(
                        completionRate == 1.0 ? Color.green : AppDesignSystem.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(completionRate * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("本週進度")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label("\(completedTasks)/\(totalTasks) 完成", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Label(formattedTime, systemImage: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 狀態圖標
            Image(systemName: completionRate == 1.0 ? "star.fill" : "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(completionRate == 1.0 ? .yellow : AppDesignSystem.accentColor)
        }
        .padding(16)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
    }
}

