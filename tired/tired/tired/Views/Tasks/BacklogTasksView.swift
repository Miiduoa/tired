import SwiftUI

@available(iOS 17.0, *)
struct BacklogTasksView: View {
    @ObservedObject var viewModel: TasksViewModel
    @State private var processingTaskIds: Set<String> = []
    @State private var showingAddTask = false

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.backlogTasks)
        let highPriority = tasks.filter { $0.priority == .high }
        let mediumPriority = tasks.filter { $0.priority == .medium }
        let lowPriority = tasks.filter { $0.priority == .low }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "tray.fill",
                title: "待辦庫是空的",
                message: "太棒了！所有任務都已經安排好了，或者新增一些備用任務吧！",
                actionTitle: "新增任務",
                action: { showingAddTask = true }
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
                                 viewModel.moveTask(fromId: sourceId, toId: destId, in: .backlog)
                                 return true
                             }
                     }
                     .buttonStyle(.plain)
                 }
             }
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // High priority
                if !highPriority.isEmpty {
                    TaskSection(title: "高優先", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(highPriority) { task in
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                                TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Medium priority
                if !mediumPriority.isEmpty {
                    TaskSection(title: "中優先", icon: "minus.circle.fill", color: .orange) {
                        ForEach(mediumPriority) { task in
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                                TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Low priority
                if !lowPriority.isEmpty {
                    TaskSection(title: "低優先", icon: "arrow.down.circle.fill", color: .blue) {
                        ForEach(lowPriority) { task in
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
