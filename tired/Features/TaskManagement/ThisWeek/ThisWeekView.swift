import SwiftUI

// MARK: - This Week View
struct ThisWeekView: View {
    @StateObject private var viewModel = ThisWeekViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView(message: "載入本週任務...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Week Load Summary
                            WeekLoadSummaryCard(summary: viewModel.weekSummary)

                            // Week Day Selector
                            WeekDaySelector(
                                weekStart: viewModel.weekStart,
                                selectedDate: selectedDate,
                                onDateSelect: { date in
                                    withAnimation {
                                        selectedDate = date
                                    }
                                }
                            )

                            // Daily Load Bar
                            DailyLoadCard(
                                date: selectedDate,
                                loadRatio: viewModel.loadRatio(for: selectedDate),
                                tasks: viewModel.tasks(for: selectedDate)
                            )

                            // Tasks for Selected Day
                            if !viewModel.tasks(for: selectedDate).isEmpty {
                                TaskSection(
                                    title: DateUtils.relativeDateDescription(selectedDate),
                                    icon: "calendar",
                                    tasks: viewModel.tasks(for: selectedDate),
                                    emptyMessage: "",
                                    onTaskTap: { task in
                                        viewModel.selectedTask = task
                                    },
                                    onTaskComplete: { task in
                                        Task { await viewModel.completeTask(task) }
                                    },
                                    onTaskFocusToggle: nil
                                )
                            }

                            // Unscheduled Tasks
                            if !viewModel.unscheduledDeadlineThisWeek.isEmpty {
                                TaskSection(
                                    title: "本週到期但未排程",
                                    icon: "exclamationmark.triangle.fill",
                                    tasks: viewModel.unscheduledDeadlineThisWeek,
                                    emptyMessage: "",
                                    onTaskTap: { task in
                                        viewModel.selectedTask = task
                                    },
                                    onTaskComplete: { task in
                                        Task { await viewModel.completeTask(task) }
                                    },
                                    onTaskFocusToggle: nil
                                )
                            }

                            // Overdue Unscheduled
                            if !viewModel.overdueUnscheduled.isEmpty {
                                TaskSection(
                                    title: "最近 7 天逾期但未排程",
                                    icon: "clock.badge.exclamationmark.fill",
                                    tasks: viewModel.overdueUnscheduled,
                                    emptyMessage: "",
                                    onTaskTap: { task in
                                        viewModel.selectedTask = task
                                    },
                                    onTaskComplete: { task in
                                        Task { await viewModel.completeTask(task) }
                                    },
                                    onTaskFocusToggle: nil
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadTasks()
                    }
                }
            }
            .navigationTitle("This Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.goToPreviousWeek() }) {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Autoplan button
                        Button(action: {
                            Task {
                                await viewModel.runAutoplan()
                            }
                        }) {
                            if viewModel.isRunningAutoplan {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(viewModel.isRunningAutoplan)

                        Button(action: { viewModel.goToNextWeek() }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadTasks()
        }
        .sheet(item: $viewModel.selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(isPresented: $viewModel.showAutoplanResult) {
            if let result = viewModel.autoplanResult {
                AutoplanResultSheet(
                    result: result,
                    onDismiss: {
                        viewModel.showAutoplanResult = false
                    }
                )
            }
        }
    }
}

// MARK: - Week Load Summary Card
struct WeekLoadSummaryCard: View {
    let summary: CapacityCalculator.WeekLoadSummary?

    var body: some View {
        if let summary = summary {
            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        Text(summary.mood)
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("本週壓力")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            Text(loadLevelText(summary.avgRatio))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(loadLevelColor(summary.avgRatio))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(summary.avgRatio * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)

                            Text("平均負載")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Text(summary.suggestion)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    private func loadLevelText(_ ratio: Double) -> String {
        let level = CapacityCalculator.loadLevel(for: ratio)
        return level.description
    }

    private func loadLevelColor(_ ratio: Double) -> Color {
        let level = CapacityCalculator.loadLevel(for: ratio)
        return Color(hex: level.color) ?? .blue
    }
}

// MARK: - Daily Load Card
struct DailyLoadCard: View {
    let date: Date
    let loadRatio: Double
    let tasks: [Task]

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateUtils.formatDisplayDate(date))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(tasks.count) 個任務")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(loadRatio * 100))%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(loadLevelColor(loadRatio))

                        Text("負載")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                CapacityBar(ratio: loadRatio, height: 8)
            }
        }
    }

    private func loadLevelColor(_ ratio: Double) -> Color {
        let level = CapacityCalculator.loadLevel(for: ratio)
        return Color(hex: level.color) ?? .blue
    }
}

// MARK: - Autoplan Result Sheet
struct AutoplanResultSheet: View {
    let result: AutoplanResult
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Success Summary
                        GlassCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.green)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("自動排程完成")
                                            .font(.system(size: 18, weight: .bold))

                                        Text("已排程 \(result.scheduledTasks.count) 個任務")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                        }

                        // Scheduled Tasks
                        if !result.scheduledTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("已排程任務")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                ForEach(result.scheduledTasks) { task in
                                    GlassCard {
                                        HStack(spacing: 12) {
                                            Image(systemName: "checkmark.circle")
                                                .foregroundColor(.green)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(task.title)
                                                    .font(.system(size: 14, weight: .medium))

                                                if let planned = task.plannedWorkDate {
                                                    Text(DateUtils.formatDisplayDate(planned))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary)
                                                }
                                            }

                                            Spacer()

                                            GlassBadge(
                                                text: task.priority.displayName,
                                                style: badgeStyle(for: task.priority)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Failed Tasks
                        if !result.failedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("無法排程的任務")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                ForEach(result.failedTasks, id: \.task.id) { failedItem in
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.orange)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(failedItem.task.title)
                                                        .font(.system(size: 14, weight: .medium))

                                                    Text(failedItem.reason.description)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.orange)
                                                }

                                                Spacer()
                                            }

                                            // Action Buttons
                                            HStack(spacing: 8) {
                                                GlassButton(
                                                    title: "手動排程",
                                                    style: .ghost,
                                                    icon: "calendar.badge.plus",
                                                    action: {
                                                        // TODO: Navigate to task detail for manual scheduling
                                                    }
                                                )
                                                .frame(maxWidth: .infinity)

                                                if failedItem.reason == .deadlineTooClose {
                                                    GlassButton(
                                                        title: "調整截止日期",
                                                        style: .ghost,
                                                        icon: "calendar.badge.clock",
                                                        action: {
                                                            // TODO: Show date picker to adjust deadline
                                                        }
                                                    )
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Suggestions
                        if !result.failedTasks.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text("建議")
                                            .font(.system(size: 16, weight: .semibold))
                                    }

                                    Text(suggestionText(for: result))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("自動排程結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func badgeStyle(for priority: TaskPriority) -> GlassBadge.Style {
        switch priority {
        case .P0: return .destructive
        case .P1: return .warning
        case .P2: return .primary
        case .P3: return .secondary
        case .P4: return .secondary
        }
    }

    private func suggestionText(for result: AutoplanResult) -> String {
        let failureReasons = result.failedTasks.map { $0.reason }

        if failureReasons.contains(.capacityOverload) {
            return "本週容量已滿。考慮：1) 延後部分任務到下週 2) 調整每日容量設定 3) 減少事件佔用時間"
        } else if failureReasons.contains(.deadlineTooClose) {
            return "某些任務的截止日期太近。建議盡快手動排程或調整截止日期。"
        } else if failureReasons.contains(.dependencyNotScheduled) {
            return "某些任務的前置任務尚未完成。請先處理前置任務。"
        } else {
            return "某些任務暫時無法排程。可以嘗試手動排程或調整任務屬性。"
        }
    }
}

// MARK: - Preview
struct ThisWeekView_Previews: PreviewProvider {
    static var previews: some View {
        ThisWeekView()
            .environmentObject(AppCoordinator())
    }
}
