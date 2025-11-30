import SwiftUI

@available(iOS 17.0, *)
struct TodayTasksView: View {
    @ObservedObject var viewModel: TasksViewModel
    @State private var processingTaskIds: Set<String> = []
    @State private var showingAddTask = false

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.todayTasks)
        let overdueTasks = tasks.filter { $0.isOverdue }
        let dueSoonTasks = tasks.filter { $0.isDueSoon && !$0.isOverdue }
        let normalTasks = tasks.filter { !$0.isOverdue && !$0.isDueSoon }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "sun.max.fill",
                title: "今天沒有任務",
                message: "享受美好的一天，或是安排一些任務來保持節奏！",
                actionTitle: "新增任務",
                action: { showingAddTask = true },
                secondaryActionTitle: "智能排程",
                secondaryAction: { 
                    NotificationCenter.default.post(name: .showAutoplan, object: nil)
                }
            )
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
        } else if viewModel.sortOption == .custom {
             // 自定義排序模式：顯示單一列表並支援拖拽
             LazyVStack(spacing: AppDesignSystem.paddingMedium) {
                 ForEach(tasks) { task in
                     NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                         TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                             .draggable(task.id ?? "")
                             .dropDestination(for: String.self) { items, location in
                                 guard let sourceId = items.first, let destId = task.id else { return false }
                                 viewModel.moveTask(fromId: sourceId, toId: destId, in: .today)
                                 return true
                             }
                     }
                     .buttonStyle(.plain)
                 }
             }
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // Overdue section
                if !overdueTasks.isEmpty {
                    TaskSection(title: "已過期", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(overdueTasks) { task in
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                                TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Due soon section
                if !dueSoonTasks.isEmpty {
                    TaskSection(title: "即將到期", icon: "clock.fill", color: .orange) {
                        ForEach(dueSoonTasks) { task in
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                                TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Normal tasks
                if !normalTasks.isEmpty {
                    TaskSection(title: "今日任務", icon: "checklist", color: .primary) {
                        ForEach(normalTasks) { task in
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                                TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
