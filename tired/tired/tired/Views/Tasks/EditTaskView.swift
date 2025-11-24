import SwiftUI

@available(iOS 17.0, *)
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel

    @Binding var task: Task

    @StateObject private var orgViewModel = OrganizationsViewModel()
    @State private var title: String
    @State private var category: TaskCategory
    @State private var priority: TaskPriority
    @State private var deadline: Date
    @State private var hasDeadline: Bool
    @State private var estimatedMinutes: String
    @State private var description: String
    @State private var hasPlannedDate: Bool
    @State private var plannedDate: Date
    @State private var isDateLocked: Bool
    @State private var sourceOrgId: String?

    init(task: Binding<Task>, viewModel: TasksViewModel) {
        self._task = task
        self.viewModel = viewModel

        _title = State(initialValue: task.wrappedValue.title)
        _category = State(initialValue: task.wrappedValue.category)
        _priority = State(initialValue: task.wrappedValue.priority)
        _deadline = State(initialValue: task.wrappedValue.deadlineAt ?? Date())
        _hasDeadline = State(initialValue: task.wrappedValue.deadlineAt != nil)
        _estimatedMinutes = State(initialValue: task.wrappedValue.estimatedMinutes.map { String($0) } ?? "")
        _description = State(initialValue: task.wrappedValue.description ?? "")
        _hasPlannedDate = State(initialValue: task.wrappedValue.plannedDate != nil)
        _plannedDate = State(initialValue: task.wrappedValue.plannedDate ?? Date())
        _isDateLocked = State(initialValue: task.wrappedValue.isDateLocked)
        _sourceOrgId = State(initialValue: task.wrappedValue.sourceOrgId)
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
                                    .fill(Color.forCategory(category))
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

                    Toggle("設定排程日期", isOn: $hasPlannedDate)
                    if hasPlannedDate {
                        DatePicker("排程到", selection: $plannedDate, displayedComponents: [.date])
                        Toggle("鎖定排程日期", isOn: $isDateLocked)
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

                Section("歸屬身份") {
                    if task.sourceType == .manual {
                        Picker("任務歸屬", selection: $sourceOrgId) {
                            Text("個人任務").tag(nil as String?)
                            ForEach(orgViewModel.myMemberships, id: \.id) { membershipWithOrg in
                                if let org = membershipWithOrg.organization, let orgId = org.id {
                                    Text(org.name).tag(orgId as String?)
                                }
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } else {
                        Text(task.sourceOrgId != nil ? "來自組織任務，不可修改歸屬" : "外部來源任務，不可修改歸屬")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
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
        updatedTask.plannedDate = hasPlannedDate ? plannedDate : nil
        updatedTask.isDateLocked = hasPlannedDate ? isDateLocked : false
        if task.sourceType == .manual {
            updatedTask.sourceOrgId = sourceOrgId
        }

        viewModel.updateTask(updatedTask)
        task = updatedTask
        dismiss()
    }
}
