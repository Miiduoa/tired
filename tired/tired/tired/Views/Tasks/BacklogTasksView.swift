import SwiftUI

@available(iOS 17.0, *)
struct BacklogTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.backlogTasks)
        let highPriority = tasks.filter { $0.priority == .high }
        let mediumPriority = tasks.filter { $0.priority == .medium }
        let lowPriority = tasks.filter { $0.priority == .low }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "tray.fill",
                title: "沒有待辦任務",
                message: "所有任務都已安排好了！"
            )
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // High priority
                if !highPriority.isEmpty {
                    TaskSection(title: "高優先", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(highPriority) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Medium priority
                if !mediumPriority.isEmpty {
                    TaskSection(title: "中優先", icon: "minus.circle.fill", color: .orange) {
                        ForEach(mediumPriority) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Low priority
                if !lowPriority.isEmpty {
                    TaskSection(title: "低優先", icon: "arrow.down.circle.fill", color: .blue) {
                        ForEach(lowPriority) { task in
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
