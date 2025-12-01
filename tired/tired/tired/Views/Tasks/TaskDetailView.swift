import SwiftUI
import FirebaseAuth // Needed for current user id

@available(iOS 17.0, *)
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel // This viewModel will manage task updates
    @State var task: Task // Make task @State so comments/attachments can update it
    @State private var deletableCommentIds: Set<String> = []
    @State private var showingEditView = false
    @State private var newCommentText = ""
    @FocusState private var isCommentInputFocused: Bool
    @State private var canAddComment = false // For RBAC
    @State private var isSendingComment = false
    @State private var showDeleteConfirmation = false // For task deletion
    @State private var canEditTask = false // For RBAC
    @State private var canDeleteTask = false // For RBAC
    @State private var canToggleTaskDone = false // For RBAC
    @State private var isProcessingToggle = false
    @State private var organization: Organization?
    @State private var dependencyTasks: [Task] = [] // 依賴任務列表
    @State private var assigneeProfiles: [UserProfile] = []
    @State private var isDeleting = false
    private let organizationService = OrganizationService()
    private let taskService = TaskService()
    private let userService = UserService()
    private var taskId: String? // For fetching

    // Initializer for when the full task object is already available
    init(viewModel: TasksViewModel, task: Task) {
        self.viewModel = viewModel
        self._task = State(initialValue: task)
        self.taskId = task.id
    }
    
    // New initializer for fetching the task by its ID
    init(viewModel: TasksViewModel, taskId: String) {
        self.viewModel = viewModel
        self._task = State(initialValue: .placeholder) // Use a placeholder
        self.taskId = taskId
    }

    var body: some View {
        Group {
            if task.id == Task.placeholder.id && taskId != nil {
                ProgressView("載入任務...")
                    .onAppear {
                        fetchTask()
                    }
            } else {
                content
            }
        }
        .background(Color.appBackground)
        .navigationTitle("任務詳情")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isDeleting)
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("刪除中...")
                        .padding()
                        .background(Material.thin)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditTaskView(task: $task, viewModel: viewModel)
        }
            .confirmationDialog("刪除任務", isPresented: $showDeleteConfirmation) {
            Button("刪除", role: .destructive) {
                _Concurrency.Task {
                    await MainActor.run { isDeleting = true }
                    let success = await viewModel.deleteTaskAsync(task: task)
                    await MainActor.run {
                        isDeleting = false
                        showDeleteConfirmation = false
                        if success { dismiss() }
                    }
                }
            }
            Button("取消", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("您確定要刪除此任務嗎？此操作無法撤銷。")
        }
        .onAppear {
            _Concurrency.Task {
                await refreshTaskData()
            }
        }
        .onChange(of: task.comments ?? []) {
            _Concurrency.Task { await refreshCommentPermissions() }
        }
        .sheet(isPresented: $showRescheduleSheet) {
            NavigationView {
                Form {
                    DatePicker(
                        isReschedulingDeadline ? "新截止時間" : "新排程日期",
                        selection: $tempDate,
                        displayedComponents: isReschedulingDeadline ? [.date, .hourAndMinute] : [.date]
                    )
                    .datePickerStyle(.graphical)
                }
                .navigationTitle(isReschedulingDeadline ? "修改截止時間" : "修改排程")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showRescheduleSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            updateDate()
                            showRescheduleSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func updateDate() {
        var updatedTask = task
        if isReschedulingDeadline {
            updatedTask.deadlineAt = tempDate
        } else {
            updatedTask.plannedDate = tempDate
        }
        
        // Optimistic update
        task = updatedTask
        
        _Concurrency.Task {
            let success = await viewModel.updateTaskAsync(updatedTask)
            if !success {
                // Rollback if failed
                await MainActor.run {
                    // Re-fetch original or just reload
                    fetchTask()
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            taskContentBody
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("關閉") { dismiss() }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if canEditTask {
                    Button {
                        showingEditView = true
                    } label: {
                        Text("編輯")
                    }
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                if canDeleteTask {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
        }
    }
    
    @State private var showRescheduleSheet = false
    @State private var tempDate = Date()
    @State private var isReschedulingDeadline = true // true for deadline, false for planned date

    // ... (existing vars)

    @State private var showingFocusMode = false
    
    @ViewBuilder
    private var taskContentBody: some View {
        VStack(spacing: 0) {
            // MARK: - Hero Header
            heroHeaderSection
            
            // MARK: - Quick Actions Bar
            quickActionsBar
                .padding(.horizontal, AppDesignSystem.paddingMedium)
                .padding(.top, AppDesignSystem.paddingMedium)
            
            // MARK: - Progress Section (如有子任務)
            if let subtasks = task.subtasks, !subtasks.isEmpty {
                progressSection(subtasks: subtasks)
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.top, AppDesignSystem.paddingMedium)
            }

            // 詳細信息
            VStack(spacing: AppDesignSystem.paddingSmall) {
                // 歸屬
                if let org = organization {
                    InfoRow(icon: "building.2.fill", iconColor: .blue, title: "歸屬", value: org.name)
                } else {
                    InfoRow(icon: "person.fill", iconColor: .green, title: "歸屬", value: task.sourceOrgId == nil ? "個人" : "組織任務")
                }
                
                // 負責人
                InfoRow(icon: "person.crop.circle", iconColor: .indigo, title: "負責人", value: assigneeDisplayName)

                // 分類
                InfoRow(icon: "tag.fill", iconColor: Color(hex: task.category.color), title: "分類", value: task.category.displayName)

                // 優先級
                InfoRow(icon: "flag.fill", iconColor: priorityColor, title: "優先級", value: task.priority.displayName)

                // 截止時間
                HStack {
                    InfoRow(
                        icon: "calendar",
                        iconColor: task.isOverdue ? .red : .blue,
                        title: "截止時間",
                        value: task.deadlineAt?.formatDateTime() ?? "無"
                    )
                    
                    if canEditTask {
                        Button {
                            tempDate = task.deadlineAt ?? Date()
                            isReschedulingDeadline = true
                            showRescheduleSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if task.isOverdue && !task.isDone {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("已逾期")
                            .foregroundColor(.red)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // 預估時長
                if let minutes = task.estimatedMinutes {
                    let hours = Double(minutes) / 60.0
                    InfoRow(
                        icon: "clock.fill",
                        iconColor: .purple,
                        title: "預估時長",
                        value: String(format: "%.1f 小時", hours)
                    )
                }

                // 排程日期
                HStack {
                    InfoRow(
                        icon: "calendar.badge.clock",
                        iconColor: .orange,
                        title: "排程日期",
                        value: task.plannedDate?.formatDateTime() ?? "未排程"
                    )
                    
                    if canEditTask {
                        Button {
                            tempDate = task.plannedDate ?? Date()
                            isReschedulingDeadline = false
                            showRescheduleSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if task.isDateLocked {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                        Text("時間已鎖定")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // ... (rest of the code)

                // 標籤
                if let tags = task.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("標籤")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppDesignSystem.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppDesignSystem.accentColor.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 12)
                    }
                    .background(Color.appSecondaryBackground.opacity(0.5))
                }
                
                // 提醒
                if let reminderAt = task.reminderAt, task.reminderEnabled == true {
                    InfoRow(
                        icon: "bell.fill",
                        iconColor: .orange,
                        title: "提醒時間",
                        value: reminderAt.formatDateTime()
                    )
                }
                
                // 依賴關係
                if !task.dependsOnTaskIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("依賴任務")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        ForEach(task.dependsOnTaskIds, id: \.self) { depId in
                            let depTask = dependencyTasks.first(where: { $0.id == depId })
                            NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: depTask ?? task)) {
                                HStack {
                                    Image(systemName: depTask?.isDone == true ? "checkmark.seal.fill" : "hourglass")
                                        .foregroundColor(depTask?.isDone == true ? .green : .orange)
                                        .font(.system(size: 12))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(depTask?.title ?? "任務 \(depId)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(depTask?.isDone == true ? "已完成" : "未完成")
                                            .font(.system(size: 11))
                                            .foregroundColor(depTask?.isDone == true ? .green : .secondary)
                                    }
                                    Spacer()
                                    if let deadline = depTask?.deadlineAt {
                                        Text(deadline.formatShort())
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 12)
                    }
                    .background(Color.appSecondaryBackground.opacity(0.5))
                }
                
                // 描述
                if let description = task.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("描述")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        Text(description)
                            .font(.system(size: 15))
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }
                    .background(Color.appSecondaryBackground.opacity(0.5))
                }

                // MARK: - Subtasks Section
                if let subtasks = task.subtasks, !subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.indent")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("子任務 (\(task.completedSubtaskCount)/\(task.totalSubtaskCount))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        ProgressView(value: task.subtaskProgress)
                            .progressViewStyle(.linear)
                            .tint(AppDesignSystem.accentColor)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(subtasks.indices, id: \.self) { index in
                                HStack {
                                    Button(action: {
                                        task.subtasks?[index].isDone.toggle()
                                        if task.subtasks?[index].isDone == true {
                                            task.subtasks?[index].doneAt = Date()
                                        } else {
                                            task.subtasks?[index].doneAt = nil
                                        }
                                        updateTask()
                                    }) {
                                        Image(systemName: task.subtasks?[index].isDone == true ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(task.subtasks?[index].isDone == true ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text(subtasks[index].title)
                                        .strikethrough(task.subtasks?[index].isDone == true, color: .secondary)
                                        .foregroundColor(task.subtasks?[index].isDone == true ? .secondary : .primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .background(Color.appSecondaryBackground.opacity(0.5))
                }

                // 創建和更新時間
                VStack(spacing: 8) {
                    HStack {
                        Text("創建時間")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(task.createdAt.formatDateTime())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("更新時間")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(task.updatedAt.formatDateTime())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
            .padding(.horizontal, AppDesignSystem.paddingMedium)


            // MARK: - File Attachments Section
            if let attachments = task.fileAttachments, !attachments.isEmpty {
                VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                    Text("附件")
                        .font(AppDesignSystem.headlineFont)
                        .padding(.horizontal, AppDesignSystem.paddingMedium)

                    ForEach(attachments) { attachment in
                        FileAttachmentRow(attachment: attachment)
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                    }
                }
                .padding(.vertical, AppDesignSystem.paddingSmall)
            }

            // MARK: - Comments Section
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                Text("評論")
                    .font(AppDesignSystem.headlineFont)
                    .padding(.horizontal, AppDesignSystem.paddingMedium)

                if let comments = task.comments, !comments.isEmpty {
                    ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                        TaskCommentRow(
                            comment: comment,
                            canDelete: deletableCommentIds.contains(comment.id),
                            onDelete: {
                                let success = await viewModel.deleteComment(from: task, comment: comment)
                                if success {
                                    await MainActor.run {
                                        self.task.comments?.removeAll(where: { $0.id == comment.id })
                                        deletableCommentIds.remove(comment.id)
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                    }
                } else {
                    Text("沒有評論")
                        .font(AppDesignSystem.bodyFont)
                        .foregroundColor(.secondary)
                        .padding(AppDesignSystem.paddingMedium)
                        .frame(maxWidth: .infinity)
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                }
                
                // Comment Input
                if canAddComment {
                    HStack {
                        TextField("新增評論...", text: $newCommentText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                            .padding(.vertical, AppDesignSystem.paddingSmall)
                            .background(Material.regular)
                            .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                            .focused($isCommentInputFocused)
                        
                        Button {
                            addComment()
                        } label: {
                            if isSendingComment {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.title2)
                                    .foregroundColor(newCommentText.isEmpty ? .secondary : AppDesignSystem.accentColor)
                            }
                        }
                        .disabled(newCommentText.isEmpty || isSendingComment)
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingSmall)
                }
            }
            .padding(.vertical, AppDesignSystem.paddingSmall)
            
            Spacer(minLength: 20)
        }
    }
    
    private func fetchTask() {
        guard let taskId = taskId else { return }
        _Concurrency.Task {
            do {
                let fetched: Task = try await taskService.fetchTask(id: taskId)
                await MainActor.run {
                    self.task = fetched
                    _Concurrency.Task {
                        await refreshTaskData()
                    }
                }
            } catch {
                print("❌ Failed to fetch task with id \(taskId): \(error)")
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    private func refreshTaskData() async {
        canAddComment = await viewModel.canAddComment(to: task)
        canEditTask = await viewModel.canEdit(task: task)
        canDeleteTask = await viewModel.canDelete(task: task)
        canToggleTaskDone = await viewModel.canToggleDone(task: task)
        await refreshCommentPermissions()
        
        if let orgId = task.sourceOrgId {
            if let org = try? await organizationService.fetchOrganization(id: orgId) {
                await MainActor.run { organization = org }
            }
        }
        
        if let assignees = task.assigneeUserIds, !assignees.isEmpty {
            if let profiles = try? await userService.fetchUserProfiles(userIds: assignees) {
                let ordered = assignees.compactMap { profiles[$0] }
                await MainActor.run { assigneeProfiles = ordered }
            }
        } else if let profile = viewModel.userProfile {
            await MainActor.run { assigneeProfiles = [profile] }
        }
        
        await loadDependencyTasks()
    }
    
    private func loadDependencyTasks() async {
        guard !task.dependsOnTaskIds.isEmpty else { return }
        
        var loadedTasks: [Task] = []
        for depId in task.dependsOnTaskIds {
            do {
                let depTask = try await taskService.fetchTask(id: depId)
                loadedTasks.append(depTask)
            } catch {
                print("❌ Error loading dependency task \(depId): \(error)")
            }
        }
        
        await MainActor.run {
            dependencyTasks = loadedTasks
        }
    }
    
    private func addComment() {
        guard !newCommentText.isEmpty else { return }
        
        _Concurrency.Task {
            await MainActor.run { isSendingComment = true }
            if let newComment = await viewModel.addComment(to: task, content: newCommentText) {
                await MainActor.run {
                    if task.comments == nil { task.comments = [] }
                    task.comments?.append(newComment)
                    deletableCommentIds.insert(newComment.id)
                    newCommentText = "" // Clear input field
                    isCommentInputFocused = false
                }
            }
            await MainActor.run { isSendingComment = false }
        }
    }

    private func refreshCommentPermissions() async {
        guard let comments = task.comments else {
            await MainActor.run { deletableCommentIds = [] }
            return
        }
        var allowed = Set<String>()
        for comment in comments {
            let canDelete = await viewModel.canDeleteComment(from: task, comment: comment)
            if canDelete { allowed.insert(comment.id) }
        }
        await MainActor.run { deletableCommentIds = allowed }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    private var assigneeDisplayName: String {
        if !assigneeProfiles.isEmpty {
            let names = assigneeProfiles.map { $0.name }
            if names.count == 1 { return names[0] }
            let leading = names.prefix(2).joined(separator: "、")
            return "\(leading)\(names.count > 2 ? " 等\(names.count)人" : "")"
        }
        if let assigneeId = task.assigneeUserIds?.first, assigneeId == task.userId {
            return "自己"
        }
        if task.assigneeUserIds != nil {
            return "載入中..."
        }
        return "未指定（預設自己）"
    }
    
    private var dependencyContext: [Task] {
        viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
    }

    private func updateTask() {
        _Concurrency.Task {
            let success = await viewModel.updateTaskAsync(task)
            if !success {
                // If the update fails, we should probably revert the state.
                // For now, let's just log it.
                print("Failed to update task with subtask changes.")
            }
        }
    }
    
    // MARK: - Hero Header Section
    
    private var heroHeaderSection: some View {
        VStack(spacing: 0) {
            // 背景漸變
            ZStack(alignment: .bottom) {
                // 背景色（基於分類）
                LinearGradient(
                    colors: [Color(hex: task.category.color).opacity(0.3), Color.appPrimaryBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                
                // 內容
                VStack(spacing: 12) {
                    // 狀態徽章
                    HStack(spacing: 8) {
                        // 優先級徽章
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                            Text(task.priority.displayName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.15))
                        .cornerRadius(6)
                        
                        // 分類徽章
                        HStack(spacing: 4) {
                            Text(task.category.displayName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: task.category.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: task.category.color).opacity(0.15))
                        .cornerRadius(6)
                        
                        // 逾期警告
                        if task.isOverdue && !task.isDone {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("已逾期")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    
                    // 標題和完成狀態
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            toggleTaskCompletion()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(task.isDone ? Color.green : Color.gray.opacity(0.3), lineWidth: 3)
                                    .frame(width: 36, height: 36)
                                
                                if task.isDone {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(!canToggleTaskDone || isProcessingToggle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 22, weight: .bold))
                                .strikethrough(task.isDone)
                                .foregroundColor(task.isDone ? .secondary : .primary)
                                .lineLimit(2)
                            
                            if let deadline = task.deadlineAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                    Text(deadline.formatDateTime())
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(task.isOverdue ? .red : .secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.bottom, AppDesignSystem.paddingMedium)
                }
            }
        }
    }
    
    // MARK: - Quick Actions Bar
    
    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            // 專注模式
            if !task.isDone {
                QuickActionButton(
                    icon: "timer",
                    label: "專注",
                    color: .orange
                ) {
                    showingFocusMode = true
                }
                .sheet(isPresented: $showingFocusMode) {
                    FocusModeView(task: $task)
                }
            }
            
            // 重新排程
            if canEditTask {
                QuickActionButton(
                    icon: "calendar.badge.clock",
                    label: "排程",
                    color: .blue
                ) {
                    tempDate = task.plannedDate ?? Date()
                    isReschedulingDeadline = false
                    showRescheduleSheet = true
                }
            }
            
            // 編輯
            if canEditTask {
                QuickActionButton(
                    icon: "pencil",
                    label: "編輯",
                    color: .purple
                ) {
                    showingEditView = true
                }
            }
            
            // 刪除
            if canDeleteTask {
                QuickActionButton(
                    icon: "trash",
                    label: "刪除",
                    color: .red
                ) {
                    showDeleteConfirmation = true
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, AppDesignSystem.paddingSmall)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Progress Section
    
    private func progressSection(subtasks: [Subtask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("進度")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount) 完成")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [AppDesignSystem.accentColor, AppDesignSystem.accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * task.subtaskProgress, height: 12)
                        .animation(.spring(response: 0.3), value: task.subtaskProgress)
                }
            }
            .frame(height: 12)
            
            // 子任務列表（可折疊）
            VStack(spacing: 8) {
                ForEach(subtasks.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Button {
                            task.subtasks?[index].isDone.toggle()
                            if task.subtasks?[index].isDone == true {
                                task.subtasks?[index].doneAt = Date()
                            } else {
                                task.subtasks?[index].doneAt = nil
                            }
                            updateTask()
                        } label: {
                            Image(systemName: subtasks[index].isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(subtasks[index].isDone ? .green : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        
                        Text(subtasks[index].title)
                            .font(.system(size: 14))
                            .strikethrough(subtasks[index].isDone)
                            .foregroundColor(subtasks[index].isDone ? .secondary : .primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Toggle Task Completion
    
    private func toggleTaskCompletion() {
        let oldValue = task.isDone
        withAnimation(.spring(response: 0.3)) {
            task.isDone.toggle()
        }
        
        _Concurrency.Task {
            guard !isProcessingToggle else { return }
            await MainActor.run { isProcessingToggle = true }
            
            if canToggleTaskDone {
                let success = await viewModel.toggleTaskDoneAsync(task: task)
                if !success {
                    await MainActor.run {
                        withAnimation {
                            task.isDone = oldValue
                        }
                    }
                }
            } else {
                ToastManager.shared.showToast(message: "您沒有權限變更任務完成狀態。", type: .error)
                await MainActor.run {
                    withAnimation {
                        task.isDone = oldValue
                    }
                }
            }
            
            await MainActor.run { isProcessingToggle = false }
        }
    }
}

// MARK: - Quick Action Button

@available(iOS 17.0, *)
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Comment Row

@available(iOS 17.0, *)
struct TaskCommentRow: View {
    let comment: TaskComment
    let canDelete: Bool
    var onDelete: (() async -> Void)?
    
    @State private var authorProfile: UserProfile?
    @State private var isDeleting = false
    private let userService = UserService()
    
    var body: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
            
            NavigationLink(destination: UserProfileView(userId: comment.authorUserId)) {
                HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
                    // Avatar
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(authorProfile?.name.prefix(1) ?? "?").uppercased())
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        )
                    
                    VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                        HStack {
                            Text(authorProfile?.name ?? "未知用戶")
                                .font(AppDesignSystem.captionFont.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text(comment.createdAt.formatShort())
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(comment.content)
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
            
            if canDelete {
                Button(role: .destructive) {
                    _Concurrency.Task {
                        guard !isDeleting else { return }
                        await MainActor.run { isDeleting = true }
                        await onDelete?()
                        await MainActor.run { isDeleting = false }
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .disabled(isDeleting)
                .buttonStyle(.plain)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
        .onAppear {
            _Concurrency.Task {
                authorProfile = try? await userService.fetchUserProfile(userId: comment.authorUserId)
            }
        }
    }
}


// MARK: - File Attachment Row

@available(iOS 17.0, *)
struct FileAttachmentRow: View {
    let attachment: FileAttachment

    var body: some View {
        HStack {
            Image(systemName: iconForFileType(attachment.fileType))
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(attachment.fileName)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.primary)
                Text("上傳於 \(attachment.uploadedAt.formatShort())")
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Optional: Button to download/view
            if let url = URL(string: attachment.fileUrl) {
                Link(destination: url) {
                    Image(systemName: "safari")
                }
            } else {
                Image(systemName: "safari")
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
    }
    
    private func iconForFileType(_ fileType: String) -> String {
        if fileType.hasPrefix("image") {
            return "photo"
        } else if fileType.contains("pdf") {
            return "doc.text.fill"
        } else if fileType.contains("word") {
            return "doc.text.fill"
        } else if fileType.contains("excel") || fileType.contains("spreadsheet") {
            return "tablecells"
        } else if fileType.contains("presentation") {
            return "rectangle.on.rectangle"
        }
        return "doc"
    }
}

// MARK: - Info Row (Moved to TaskDetailView to avoid conflicts)

@available(iOS 17.0, *)
struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
