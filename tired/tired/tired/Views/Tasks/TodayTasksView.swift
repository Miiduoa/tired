import SwiftUI

@available(iOS 17.0, *)
struct TodayTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.todayTasks)
        let overdueTasks = tasks.filter { $0.isOverdue }
        let dueSoonTasks = tasks.filter { $0.isDueSoon && !$0.isOverdue }
        let normalTasks = tasks.filter { !$0.isOverdue && !$0.isDueSoon }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "sun.max.fill",
                title: "今天沒有任務",
                message: "享受美好的一天吧！"
            )
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // Overdue section
                if !overdueTasks.isEmpty {
                    TaskSection(title: "已過期", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(overdueTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Due soon section
                if !dueSoonTasks.isEmpty {
                    TaskSection(title: "即將到期", icon: "clock.fill", color: .orange) {
                        ForEach(dueSoonTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Normal tasks
                if !normalTasks.isEmpty {
                    TaskSection(title: "今日任務", icon: "checklist", color: .primary) {
                        ForEach(normalTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }
            }
        }
    }
}
