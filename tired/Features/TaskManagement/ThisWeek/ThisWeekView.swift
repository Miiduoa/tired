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
                    Button(action: { viewModel.goToNextWeek() }) {
                        Image(systemName: "chevron.right")
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

// MARK: - Preview
struct ThisWeekView_Previews: PreviewProvider {
    static var previews: some View {
        ThisWeekView()
            .environmentObject(AppCoordinator())
    }
}
