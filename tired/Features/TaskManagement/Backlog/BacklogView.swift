import SwiftUI

// MARK: - Backlog View
struct BacklogView: View {
    @StateObject private var viewModel = BacklogViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator

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
                    LoadingView(message: "載入 Backlog...")
                } else if viewModel.tasks.isEmpty {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "Backlog 是空的",
                        message: "所有任務都已排程或完成",
                        actionTitle: "新增任務",
                        action: {
                            viewModel.showQuickAdd = true
                        }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.tasks) { task in
                                TaskRow(
                                    task: task,
                                    showDate: false,
                                    showCourse: true,
                                    onTap: { viewModel.selectedTask = task },
                                    onComplete: { Task { await viewModel.completeTask(task) } },
                                    onFocusToggle: nil
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
            .navigationTitle("Backlog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.showQuickAdd = true }) {
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
        .sheet(isPresented: $viewModel.showQuickAdd) {
            QuickAddSheet(onDismiss: {
                viewModel.showQuickAdd = false
                Task { await viewModel.loadTasks() }
            })
        }
        .sheet(item: $viewModel.selectedTask) { task in
            Text("Task Detail: \(task.title)")
        }
    }
}

// MARK: - Quick Add Sheet
struct QuickAddSheet: View {
    @Environment(\.dismiss) var dismiss
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var category: TaskCategory = .personal
    @State private var priority: TaskPriority = .P2
    @State private var estimatedMinutes = 30

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
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("標題")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    TextField("要做什麼？", text: $title)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("分類")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    CategoryPicker(category: $category, excludeSchool: false)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("優先度")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    PriorityPicker(priority: $priority)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("預估時間")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    HStack {
                                        TextField("", value: $estimatedMinutes, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.numberPad)
                                            .frame(width: 80)

                                        Text("分鐘")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("快速新增")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        Task {
                            await createTask()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createTask() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }

        let task = Task(
            userId: userId,
            title: title,
            category: category,
            priority: priority,
            estimatedEffortMin: estimatedMinutes
        )

        do {
            try await TaskService.shared.createTask(task)
            dismiss()
            onDismiss()
        } catch {
            print("❌ Error creating task: \(error.localizedDescription)")
        }
    }
}
