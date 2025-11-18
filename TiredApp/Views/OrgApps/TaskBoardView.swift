import SwiftUI
import Combine

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
                            viewModel.syncToPersonalTasks(task: task)
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
    let onSync: () -> Void

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

                Button(action: onSync) {
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

        Task {
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

// MARK: - TaskBoard ViewModel

class TaskBoardViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var canManage = false

    let appInstanceId: String
    let organizationId: String
    private let taskService = TaskService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(appInstanceId: String, organizationId: String) {
        self.appInstanceId = appInstanceId
        self.organizationId = organizationId
        setupSubscriptions()
        checkPermissions()
    }

    private func setupSubscriptions() {
        // 獲取組織任務（sourceType = org_task, sourceAppInstanceId = appInstanceId）
        FirebaseManager.shared.db
            .collection("tasks")
            .whereField("sourceAppInstanceId", isEqualTo: appInstanceId)
            .whereField("sourceType", isEqualTo: TaskSourceType.orgTask.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching org tasks: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let tasks = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                DispatchQueue.main.async {
                    self?.tasks = tasks
                }
            }
    }

    private func checkPermissions() {
        guard let userId = userId else { return }

        Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: organizationId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.canManage = membership.role == .owner || membership.role == .admin
                    }
                }
            } catch {
                print("❌ Error checking permissions: \(error)")
            }
        }
    }

    func createOrgTask(title: String, description: String?, category: TaskCategory, deadline: Date?, estimatedMinutes: Int) async throws {
        guard let userId = userId else {
            throw NSError(domain: "TaskBoardViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        // 創建組織任務（沒有 userId，或使用特殊標記）
        let task = Task(
            userId: "org_\(organizationId)", // 使用組織ID標記
            sourceOrgId: organizationId,
            sourceAppInstanceId: appInstanceId,
            sourceType: .orgTask,
            title: title,
            description: description,
            category: category,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes
        )

        try await taskService.createTask(task)
    }

    func syncToPersonalTasks(task: Task) {
        guard let userId = userId else { return }

        Task {
            do {
                // 創建個人任務副本
                var personalTask = task
                personalTask.id = nil // 清除ID以創建新任務
                personalTask.userId = userId
                personalTask.sourceType = .orgTask
                personalTask.plannedDate = nil // 讓用戶自己排程

                try await taskService.createTask(personalTask)

                print("✅ Task synced to personal tasks")
            } catch {
                print("❌ Error syncing task: \(error)")
            }
        }
    }
}
