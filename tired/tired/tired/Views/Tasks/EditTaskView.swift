import SwiftUI

@available(iOS 17.0, *)
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel

    let task: Task

    @State private var title: String
    @State private var category: TaskCategory
    @State private var priority: TaskPriority
    @State private var deadline: Date
    @State private var hasDeadline: Bool
    @State private var estimatedMinutes: String
    @State private var description: String

    init(task: Task, viewModel: TasksViewModel) {
        self.task = task
        self.viewModel = viewModel

        _title = State(initialValue: task.title)
        _category = State(initialValue: task.category)
        _priority = State(initialValue: task.priority)
        _deadline = State(initialValue: task.deadlineAt ?? Date())
        _hasDeadline = State(initialValue: task.deadlineAt != nil)
        _estimatedMinutes = State(initialValue: task.estimatedMinutes.map { String($0) } ?? "")
        _description = State(initialValue: task.description ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("任務標題", text: $title)

                    Picker("分類", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }

                    Picker("優先級", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }

                Section("時間") {
                    Toggle("設定截止時間", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "截止時間",
                            selection: $deadline,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    HStack {
                        Text("預估時長")
                        TextField("分鐘", text: $estimatedMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("描述（選填）") {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
            }
            .navigationTitle("編輯任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let estimatedMins = Int(estimatedMinutes.trimmingCharacters(in: .whitespacesAndNewlines))

        var updatedTask = task
        updatedTask.title = trimmedTitle
        updatedTask.category = category
        updatedTask.priority = priority
        updatedTask.deadlineAt = hasDeadline ? deadline : nil
        updatedTask.estimatedMinutes = estimatedMins
        updatedTask.description = description.isEmpty ? nil : description

        viewModel.updateTask(updatedTask)
        dismiss()
    }
}
