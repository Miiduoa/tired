import SwiftUI
import FirebaseAuth

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
    @State private var subtasks: [Subtask]
    @State private var newSubtaskTitle: String = ""
    @State private var completionPercentage: Int
    @State private var sourceOrgId: String?
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var assigneeUserId: String?
    @State private var assigneeOptions: [AssigneeOption] = []
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var dependencySelections: Set<String>
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var canEdit: Bool = true
    @State private var canDelete: Bool = true
    
    private let organizationService = OrganizationService()
    private let userService = UserService()

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
        
        let existingSubtasks = (task.wrappedValue.subtasks ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let derivedCompletion: Int
        if let storedCompletion = task.wrappedValue.completionPercentage {
            derivedCompletion = storedCompletion
        } else if !existingSubtasks.isEmpty {
            let doneCount = existingSubtasks.filter { $0.isDone }.count
            derivedCompletion = Int((Double(doneCount) / Double(existingSubtasks.count)) * 100)
        } else {
            derivedCompletion = task.wrappedValue.isDone ? 100 : 0
        }
        _subtasks = State(initialValue: existingSubtasks)
        _completionPercentage = State(initialValue: derivedCompletion)
        
        _tags = State(initialValue: task.wrappedValue.tags ?? [])
        _assigneeUserId = State(initialValue: task.wrappedValue.assigneeUserIds?.first ?? task.wrappedValue.userId)
        _reminderEnabled = State(initialValue: task.wrappedValue.reminderEnabled ?? false)
        _reminderDate = State(initialValue: task.wrappedValue.reminderAt ?? task.wrappedValue.deadlineAt ?? Date().addingTimeInterval(3600))
        _dependencySelections = State(initialValue: Set(task.wrappedValue.dependsOnTaskIds))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本資訊") {
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

                Section("時間與排程") {
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

                Section("進度與子任務") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("完成度")
                            Spacer()
                            Text("\(completionPercentage)%")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(completionPercentage) },
                                set: { completionPercentage = Int($0) }
                            ),
                            in: 0...100,
                            step: 5
                        )
                        .tint(AppDesignSystem.accentColor)
                    }
                    
                    HStack {
                        TextField("新增子任務", text: $newSubtaskTitle)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit { addSubtask() }
                        
                        Button {
                            addSubtask()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppDesignSystem.accentColor)
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    if subtasks.isEmpty {
                        Text("目前沒有子任務")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(subtasks.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Button {
                                    toggleSubtaskDone(at: index)
                                } label: {
                                    Image(systemName: subtasks[index].isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(subtasks[index].isDone ? AppDesignSystem.accentColor : .secondary)
                                }
                                
                                TextField(
                                    "子任務內容",
                                    text: Binding(
                                        get: { subtasks[index].title },
                                        set: { subtasks[index].title = $0 }
                                    )
                                )
                                .textFieldStyle(.plain)
                                .onSubmit { normalizeSubtask(at: index) }
                                
                                Spacer()
                                
                                Menu {
                                    Button("上移") { moveSubtask(at: index, direction: -1) }
                                        .disabled(index == 0)
                                    Button("下移") { moveSubtask(at: index, direction: 1) }
                                        .disabled(index == subtasks.count - 1)
                                    
                                    Divider()
                                    
                                    Button("刪除", role: .destructive) {
                                        removeSubtask(at: index)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("歸屬") {
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
                
                // 新增：標籤管理
                Section("標籤") {
                    // 顯示現有標籤
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.system(size: 13, weight: .medium))
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12))
                                        }
                                    }
                                    .foregroundColor(AppDesignSystem.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppDesignSystem.accentColor.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // 新增標籤輸入
                    HStack {
                        TextField("新增標籤", text: $newTag)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit {
                                addTag()
                            }
                        
                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(newTag.isEmpty ? .secondary : AppDesignSystem.accentColor)
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
                
                // 新增：負責人
                Section("任務負責人") {
                    if assigneeOptions.isEmpty {
                        HStack {
                            Text("載入中...")
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Picker("負責人", selection: $assigneeUserId) {
                            ForEach(assigneeOptions) { option in
                                HStack {
                                    Text(option.name)
                                    if let detail = option.detail {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(option.id as String?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                // 新增：提醒設定
                Section("提醒") {
                    Toggle("啟用提醒", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) {
                            normalizeReminderDate()
                        }
                    
                    if reminderEnabled {
                        DatePicker(
                            "提醒時間",
                            selection: $reminderDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .onChange(of: reminderDate) {
                            normalizeReminderDate()
                        }
                        
                        if hasDeadline {
                            Button {
                                reminderDate = max(Date().addingTimeInterval(300), deadline.addingTimeInterval(-900))
                            } label: {
                                Label("套用「截止前15分鐘」", systemImage: "bell.badge")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                // 新增：依賴關係
                Section("任務依賴") {
                    if dependencyCandidates.isEmpty {
                        Text("目前沒有其他未完成的任務可供依賴。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(dependencyCandidates, id: \.id) { candidate in
                            if let id = candidate.id {
                                Toggle(isOn: Binding(
                                    get: { dependencySelections.contains(id) },
                                    set: { isOn in
                                        if isOn {
                                            // 檢查循環依賴
                                            if !hasCircularDependency(taskId: task.id ?? "", newDependencyId: id) {
                                                dependencySelections.insert(id)
                                            } else {
                                                ToastManager.shared.showToast(message: "無法添加：會形成循環依賴", type: .error)
                                            }
                                        } else {
                                            dependencySelections.remove(id)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(candidate.title)
                                            .font(.system(size: 14, weight: .semibold))
                                        HStack(spacing: 8) {
                                            if let deadline = candidate.deadlineAt {
                                                Label(deadline.formatShort(), systemImage: "calendar")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Label(candidate.category.displayName, systemImage: "square.grid.2x2")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }
                        if !missingDependencies.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(missingDependencies, id: \.self) { depId in
                                    Text("未載入的依賴：\(depId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Text("受阻任務會提示需先完成前置任務。")
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isDeleting || !canEdit)
                }
                ToolbarItem(placement: .destructiveAction) {
                    if task.id != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(isSaving || isDeleting || !canDelete)
                    }
                }
            }
            .onAppear {
                _Concurrency.Task {
                    await refreshAssigneeOptions()
                    canEdit = await viewModel.canEdit(task: task)
                    canDelete = await viewModel.canDelete(task: task)
                }
                normalizeReminderDate()
            }
            .onChange(of: sourceOrgId) {
                _Concurrency.Task {
                    await refreshAssigneeOptions()
                }
            }
            .onChange(of: hasDeadline) {
                normalizeReminderDate()
            }
            .onChange(of: deadline) {
                normalizeReminderDate()
            }
            .disabled(isSaving || isDeleting || !canEdit)
        }
        .overlay {
            if isSaving || isDeleting {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView(isSaving ? "儲存中..." : "刪除中...")
                        .padding()
                        .background(Material.thin)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .confirmationDialog("刪除任務", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                _Concurrency.Task {
                    isDeleting = true
                    let success = await viewModel.deleteTaskAsync(task: task)
                    await MainActor.run {
                        isDeleting = false
                        showDeleteConfirmation = false
                        if success {
                            dismiss()
                        } else {
                            ToastManager.shared.showToast(message: "刪除失敗，請稍後再試", type: .error)
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("此操作將永久刪除任務，無法復原。")
        }
    }
    
    private var dependencyCandidates: [Task] {
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        let currentTaskId = task.id ?? ""
        return allTasks
            .filter { 
                guard let id = $0.id, id != currentTaskId, !$0.isDone else { return false }
                // 排除已經依賴於當前任務的任務（避免直接循環）
                return !$0.dependsOnTaskIds.contains(currentTaskId)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var missingDependencies: [String] {
        dependencySelections.filter { depId in
            !dependencyCandidates.contains(where: { $0.id == depId })
        }
    }
    
    private func hasCircularDependency(taskId: String, newDependencyId: String) -> Bool {
        // 如果新依賴就是當前任務，形成循環
        if taskId == newDependencyId {
            return true
        }
        
        // 檢查新依賴是否依賴於當前任務（會形成循環）
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        if let newDepTask = allTasks.first(where: { $0.id == newDependencyId }) {
            // 如果新依賴任務已經依賴於當前任務，會形成循環
            if newDepTask.dependsOnTaskIds.contains(taskId) {
                return true
            }
            
            // 遞歸檢查：如果新依賴任務依賴的任務中，有任何一個依賴於當前任務，也會形成循環
            for depId in newDepTask.dependsOnTaskIds {
                if hasCircularDependencyRecursive(taskId: taskId, checkTaskId: depId, allTasks: allTasks, visited: Set<String>()) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func hasCircularDependencyRecursive(taskId: String, checkTaskId: String, allTasks: [Task], visited: Set<String>) -> Bool {
        // 防止無限遞歸
        if visited.contains(checkTaskId) {
            return false
        }
        
        var newVisited = visited
        newVisited.insert(checkTaskId)
        
        // 如果檢查的任務就是當前任務，形成循環
        if checkTaskId == taskId {
            return true
        }
        
        // 檢查該任務的依賴
        if let checkTask = allTasks.first(where: { $0.id == checkTaskId }) {
            for depId in checkTask.dependsOnTaskIds {
                if hasCircularDependencyRecursive(taskId: taskId, checkTaskId: depId, allTasks: allTasks, visited: newVisited) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func refreshAssigneeOptions() async {
        guard Auth.auth().currentUser?.uid != nil else { return }
        
        await MainActor.run {
            assigneeOptions = []
        }
        
        if let orgId = sourceOrgId {
            await loadOrgAssignees(orgId: orgId)
        } else {
            loadPersonalAssignee()
        }
    }
    
    private func loadPersonalAssignee() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        _Concurrency.Task {
            var profile: UserProfile?
            if let existingProfile = viewModel.userProfile {
                profile = existingProfile
            } else {
                do {
                    profile = try await userService.fetchUserProfile(userId: uid)
                } catch {
                    // If fetch fails, profile will be nil and we'll use default name
                }
            }
            let option = AssigneeOption(id: uid, name: profile?.name ?? "我自己", detail: "個人任務")
            await MainActor.run {
                assigneeOptions = [option]
                if assigneeUserId == nil { assigneeUserId = uid }
            }
        }
    }
    
    private func loadOrgAssignees(orgId: String) async {
        do {
            let memberships = try await organizationService.fetchOrganizationMembers(organizationId: orgId)
            var options: [AssigneeOption] = []
            
            // 逐個獲取用戶資料
            for membership in memberships {
                let profile = try? await userService.fetchUserProfile(userId: membership.userId)
                let name = profile?.name ?? "組織成員"
                options.append(AssigneeOption(id: membership.userId, name: name, detail: "組織成員"))
            }
            
            options.sort { $0.name < $1.name }
            
            await MainActor.run {
                assigneeOptions = options
                if let first = options.first, !options.contains(where: { $0.id == assigneeUserId }) {
                    assigneeUserId = first.id
                }
            }
        } catch {
            await MainActor.run {
                assigneeOptions = []
                ToastManager.shared.showToast(message: "載入成員失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    private func normalizeReminderDate() {
        guard reminderEnabled else { return }
        var candidate = reminderDate
        if candidate < Date() {
            if hasDeadline {
                candidate = max(Date().addingTimeInterval(300), deadline.addingTimeInterval(-900))
            } else {
                candidate = Date().addingTimeInterval(900)
            }
        }
        reminderDate = candidate
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            ToastManager.shared.showToast(message: "請輸入任務標題", type: .warning)
            return
        }

        let trimmedEstimate = estimatedMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsedEstimated: Int?
        if !trimmedEstimate.isEmpty {
            guard let minutes = Int(trimmedEstimate), minutes > 0 else {
                ToastManager.shared.showToast(message: "預估時長需為正整數分鐘", type: .warning)
                return
            }
            parsedEstimated = minutes
        }
        
        guard validateSubtasks() else { return }
        let cleanedSubtasks = normalizedSubtasksForSave()
        let cleanedTags = normalizeTags()

        var updatedTask = task
        updatedTask.title = trimmedTitle
        updatedTask.category = category
        updatedTask.priority = priority
        updatedTask.deadlineAt = hasDeadline ? deadline : nil
        updatedTask.estimatedMinutes = parsedEstimated
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTask.description = trimmedDescription.isEmpty ? nil : trimmedDescription
        updatedTask.plannedDate = hasPlannedDate ? plannedDate : nil
        updatedTask.isDateLocked = hasPlannedDate ? isDateLocked : false
        if task.sourceType == .manual {
            updatedTask.sourceOrgId = sourceOrgId
        }

        // 更新標籤
        updatedTask.tags = cleanedTags.isEmpty ? nil : cleanedTags
        
        // 更新子任務與完成度
        updatedTask.subtasks = cleanedSubtasks.isEmpty ? nil : cleanedSubtasks
        updatedTask.completionPercentage = completionPercentage
        
        // 更新負責人
        if let selected = assigneeUserId {
            updatedTask.assigneeUserIds = [selected]
        } else if let existing = updatedTask.assigneeUserIds, !existing.isEmpty {
            updatedTask.assigneeUserIds = existing
        } else {
            updatedTask.assigneeUserIds = [updatedTask.userId]
        }
        
        // 更新提醒
        if reminderEnabled {
            updatedTask.reminderAt = reminderDate
            updatedTask.reminderEnabled = true
        } else {
            updatedTask.reminderAt = nil
            updatedTask.reminderEnabled = false
        }
        
        // 更新依賴關係（在保存前再次驗證，防止循環依賴）
        let finalDependencies = Array(dependencySelections)
        
        // 驗證依賴關係（防止循環依賴）
        let currentTaskId = updatedTask.id ?? ""
        if !currentTaskId.isEmpty {
            for depId in finalDependencies {
                if hasCircularDependency(taskId: currentTaskId, newDependencyId: depId) {
                    ToastManager.shared.showToast(message: "無法保存：檢測到循環依賴（任務 \(depId)）", type: .error)
                    return
                }
            }
        }
        
        updatedTask.dependsOnTaskIds = finalDependencies

        isSaving = true
        _Concurrency.Task {
            let success = await viewModel.updateTaskAsync(updatedTask)
            await MainActor.run {
                isSaving = false
                if success {
                    task = updatedTask
                    dismiss()
                } else {
                    ToastManager.shared.showToast(message: "儲存失敗，請稍後再試", type: .error)
                }
            }
        }
    }
    
    private func validateSubtasks() -> Bool {
        for subtask in subtasks {
            let trimmed = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                ToastManager.shared.showToast(message: "子任務內容不能留空", type: .warning)
                return false
            }
            if trimmed.count > 200 {
                ToastManager.shared.showToast(message: "子任務文字請少於200字", type: .warning)
                return false
            }
        }
        return true
    }
    
    private func normalizedSubtasksForSave() -> [Subtask] {
        subtasks.enumerated().map { index, subtask in
            var updated = subtask
            updated.title = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.sortOrder = index
            return updated
        }
    }
    
    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newSubtaskTitle = ""
            return
        }
        let newItem = Subtask(title: trimmed, isDone: false, sortOrder: subtasks.count)
        subtasks.append(newItem)
        newSubtaskTitle = ""
        syncCompletionFromSubtasks()
    }
    
    private func toggleSubtaskDone(at index: Int) {
        guard subtasks.indices.contains(index) else { return }
        subtasks[index].isDone.toggle()
        subtasks[index].doneAt = subtasks[index].isDone ? (subtasks[index].doneAt ?? Date()) : nil
        syncCompletionFromSubtasks()
    }
    
    private func removeSubtask(at index: Int) {
        guard subtasks.indices.contains(index) else { return }
        subtasks.remove(at: index)
        renumberSubtasks()
        syncCompletionFromSubtasks()
    }
    
    private func moveSubtask(at index: Int, direction: Int) {
        guard subtasks.indices.contains(index) else { return }
        let newIndex = index + direction
        guard subtasks.indices.contains(newIndex) else { return }
        subtasks.swapAt(index, newIndex)
        renumberSubtasks()
    }
    
    private func normalizeSubtask(at index: Int) {
        guard subtasks.indices.contains(index) else { return }
        let trimmed = subtasks[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeSubtask(at: index)
        } else {
            subtasks[index].title = trimmed
        }
    }
    
    private func renumberSubtasks() {
        for idx in subtasks.indices {
            subtasks[idx].sortOrder = idx
        }
    }
    
    private func syncCompletionFromSubtasks() {
        guard !subtasks.isEmpty else {
            completionPercentage = 0
            return
        }
        let doneCount = subtasks.filter { $0.isDone }.count
        completionPercentage = Int((Double(doneCount) / Double(subtasks.count)) * 100)
    }
    
    private func normalizeTags() -> [String] {
        var normalized: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !normalized.contains(trimmed) {
                normalized.append(trimmed)
            }
        }
        return normalized
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
    }
}

// MARK: - Assignee Option


