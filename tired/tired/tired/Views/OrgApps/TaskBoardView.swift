import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct TaskBoardView: View {
    let appInstance: OrgAppInstance
    let organizationId: String

    @StateObject private var viewModel: TaskBoardViewModel
    @State private var showingCreateTask = false

    init(appInstance: OrgAppInstance, organizationId: String) {
        self.appInstance = appInstance
        self.organizationId = organizationId
        self._viewModel = StateObject(wrappedValue: TaskBoardViewModel(
            appInstanceId: appInstance.id ?? "",
            organizationId: organizationId
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.tasks.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.tasks) { task in
                        OrgTaskCard(task: task) {
                            // This closure is now async throws
                            try await viewModel.syncToPersonalTasks(task: task)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(appInstance.name ?? "任務看板")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateOrgTaskView(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暫無任務")
                .font(.system(size: 18, weight: .semibold))

            if viewModel.canManage {
                Text("點擊右上角 + 號發布新任務")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("組織管理員會在這裡發布任務")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Org Task Card

@available(iOS 17.0, *)
struct OrgTaskCard: View {
    let task: Task
    let onSync: () async throws -> Void // Changed signature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))

                    if let description = task.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        if let deadline = task.deadlineAt {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(deadline.formatShort())
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }

                        if let estimatedHours = task.estimatedHours {
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 10))
                                Text("約 \(String(format: "%.1f", estimatedHours))h")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    // Call the onSync closure in a Task to handle async throws
                    _Concurrency.Task {
                        do {
                            try await onSync()
                            await MainActor.run {
                                ToastManager.shared.showToast(message: "任務同步成功！", type: .success)
                            }
                        } catch {
                            print("❌ Error syncing task: \(error)")
                            await MainActor.run {
                                ToastManager.shared.showToast(message: "同步失敗: \(error.localizedDescription)", type: .error)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("同步")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Create Org Task View

@available(iOS 17.0, *)
struct CreateOrgTaskView: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .school
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("任務標題", text: $title)
                    TextField("描述（選填）", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("分類", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section("時間估計") {
                    HStack {
                        Text("預估時長")
                        Spacer()
                        Text("\(String(format: "%.1f", estimatedHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                }

                Section("截止日期") {
                    Toggle("設置截止日期", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("截止時間", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("發布任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("發布") {
                        createTask()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }

    private func createTask() {
        isCreating = true

        _Concurrency.Task {
            do {
                try await viewModel.createOrgTask(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    category: category,
                    deadline: hasDeadline ? deadline : nil,
                    estimatedMinutes: Int(estimatedHours * 60)
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating task: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}
