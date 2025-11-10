import SwiftUI

// MARK: - Today View
struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView(message: "載入今天的任務...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            TodayHeader(
                                date: Date(),
                                focusCount: viewModel.focusTasks.count,
                                totalCount: viewModel.allTodayTasks.count
                            )
                            .padding(.horizontal)

                            // Empty State
                            if viewModel.allTodayTasks.isEmpty {
                                EmptyStateView(
                                    icon: "checkmark.circle.fill",
                                    title: "今天清單是空的！",
                                    message: "你可以從本週選幾個焦點，或整理收集箱",
                                    actionTitle: "查看 Backlog",
                                    action: {
                                        // TODO: Navigate to Backlog
                                    }
                                )
                                .padding()
                            } else {
                                // Four Sections
                                VStack(spacing: 16) {
                                    // 1. Overdue Deadline
                                    if !viewModel.overdueDeadlineTasks.isEmpty {
                                        TaskSection(
                                            title: "截止逾期",
                                            icon: "exclamationmark.triangle.fill",
                                            tasks: viewModel.overdueDeadlineTasks,
                                            emptyMessage: "",
                                            onTaskTap: { task in
                                                viewModel.selectedTask = task
                                            },
                                            onTaskComplete: { task in
                                                Task {
                                                    await viewModel.completeTask(task)
                                                }
                                            },
                                            onTaskFocusToggle: { task in
                                                Task {
                                                    await viewModel.toggleFocus(task)
                                                }
                                            }
                                        )
                                    }

                                    // 2. Deadline Today
                                    if !viewModel.deadlineTodayTasks.isEmpty {
                                        TaskSection(
                                            title: "今天到期",
                                            icon: "calendar.badge.clock",
                                            tasks: viewModel.deadlineTodayTasks,
                                            emptyMessage: "",
                                            onTaskTap: { task in
                                                viewModel.selectedTask = task
                                            },
                                            onTaskComplete: { task in
                                                Task {
                                                    await viewModel.completeTask(task)
                                                }
                                            },
                                            onTaskFocusToggle: { task in
                                                Task {
                                                    await viewModel.toggleFocus(task)
                                                }
                                            }
                                        )
                                    }

                                    // 3. Work Date Delayed
                                    if !viewModel.workDateDelayedTasks.isEmpty {
                                        TaskSection(
                                            title: "工作日延後",
                                            icon: "arrow.right.circle.fill",
                                            tasks: viewModel.workDateDelayedTasks,
                                            emptyMessage: "",
                                            onTaskTap: { task in
                                                viewModel.selectedTask = task
                                            },
                                            onTaskComplete: { task in
                                                Task {
                                                    await viewModel.completeTask(task)
                                                }
                                            },
                                            onTaskFocusToggle: { task in
                                                Task {
                                                    await viewModel.toggleFocus(task)
                                                }
                                            }
                                        )
                                    }

                                    // 4. Today's List
                                    if !viewModel.todayListTasks.isEmpty {
                                        TaskSection(
                                            title: "今天清單",
                                            icon: "list.bullet.circle.fill",
                                            tasks: viewModel.todayListTasks,
                                            emptyMessage: "",
                                            onTaskTap: { task in
                                                viewModel.selectedTask = task
                                            },
                                            onTaskComplete: { task in
                                                Task {
                                                    await viewModel.completeTask(task)
                                                }
                                            },
                                            onTaskFocusToggle: { task in
                                                Task {
                                                    await viewModel.toggleFocus(task)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.loadTasks()
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // TODO: Show add task sheet
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
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

// MARK: - Today Header
struct TodayHeader: View {
    let date: Date
    let focusCount: Int
    let totalCount: Int

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateUtils.formatDisplayDate(date))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        Text("今天")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text("\(focusCount)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text("焦點任務")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                if totalCount > 0 {
                    Divider()

                    HStack {
                        Text("共 \(totalCount) 個任務")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Spacer()

                        if focusCount > 3 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text("焦點太多了")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(AppCoordinator())
    }
}
