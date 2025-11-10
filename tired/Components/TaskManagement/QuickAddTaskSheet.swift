import SwiftUI

// MARK: - Quick Add Task Sheet
struct QuickAddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickAddViewModel()

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
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("任務名稱")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("輸入任務...", text: $viewModel.title)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text("優先級")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            PriorityPicker(selected: $viewModel.priority)
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("截止日期（選填）")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Toggle("設定截止日期", isOn: $viewModel.hasDeadline)

                            if viewModel.hasDeadline {
                                DatePicker("", selection: $viewModel.deadline, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("類別")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            CategoryPicker(selected: $viewModel.category)
                        }

                        // Add to Today
                        Toggle("加入今日專注", isOn: $viewModel.addToToday)
                            .font(.system(size: 16))

                        // Create Button
                        GlassButton(
                            "建立任務",
                            icon: "plus.circle.fill",
                            style: .primary
                        ) {
                            Task {
                                await viewModel.createTask()
                                if viewModel.createSuccess {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(viewModel.title.isEmpty || viewModel.isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle("快速添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Quick Add View Model
@MainActor
class QuickAddViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var priority: TaskPriority = .P2
    @Published var category: TaskCategory = .school
    @Published var hasDeadline: Bool = false
    @Published var deadline: Date = DateUtils.addDays(Date(), 7)
    @Published var addToToday: Bool = false
    @Published var isCreating: Bool = false
    @Published var createSuccess: Bool = false

    private let taskService = TaskService.shared

    func createTask() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }
        isCreating = true

        var task = Task(
            userId: userId,
            title: title,
            description: "",
            category: category,
            priority: priority,
            state: .open,
            isTodayFocus: addToToday
        )

        if hasDeadline {
            task.deadlineAt = deadline
            task.deadlineDate = DateUtils.formatDateKey(deadline)
        }

        do {
            try await taskService.createTask(task)
            ToastManager.shared.showSuccess("任務「\(title)」已建立")
            createSuccess = true
        } catch {
            print("❌ Error creating task: \(error.localizedDescription)")
            ToastManager.shared.showError("建立任務失敗")
        }

        isCreating = false
    }
}

// MARK: - Preview
struct QuickAddTaskSheet_Previews: PreviewProvider {
    static var previews: some View {
        QuickAddTaskSheet()
    }
}
