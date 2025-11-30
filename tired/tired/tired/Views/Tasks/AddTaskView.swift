import SwiftUI
import FirebaseAuth
import UserNotifications

@available(iOS 17.0, *)
struct AddTaskView: View {
    @ObservedObject var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var orgViewModel = OrganizationsViewModel()

    @State private var title = ""
    @State private var description = ""
    @State private var taskType: TaskType = .generic
    @State private var category: TaskCategory = .personal
    @State private var priority: TaskPriority = .medium
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var hasPlannedDate = false
    @State private var plannedDate = Date()
    @State private var subtasks: [String] = []
    @State private var newSubtask = ""
    @State private var deletingSubtaskIndex: Int? = nil
    @State private var showClearAllConfirmation = false
    @State private var completionPercentage: Int = 0
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var tagSuggestions: [String] = []
    @State private var showTagSuggestions = false
    @State private var attachments: [URL] = []
    @State private var showAttachmentPicker = false
    @State private var isCreating = false
    @State private var selectedOrgId: String?
    @State private var assigneeUserId: String?
    @State private var assigneeOptions: [AssigneeOption] = []
    @State private var reminderEnabled = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var dependencySelections: Set<String> = []
    @State private var recurrenceRule: RecurrenceRule? = nil
    @State private var recurrenceEndDate: Date? = nil
    @State private var showTemplatePicker = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var notificationPermissionGranted = false
    @State private var showNotificationPermissionAlert = false
    @State private var isRequestingNotificationPermission = false
    
    // UI State
    @State private var showAdvancedOptions = false
    
    private let organizationService = OrganizationService()
    private let userService = UserService()
    private let notificationService = NotificationService.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        AddTaskBasicInfoView(
                            title: $title,
                            description: $description,
                            category: $category,
                            priority: $priority,
                            hasDeadline: $hasDeadline,
                            deadline: $deadline
                        )
                        
                        // Advanced Options Toggle
                        Button {
                            withAnimation(.spring()) {
                                showAdvancedOptions.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showAdvancedOptions ? "隱藏進階選項" : "顯示進階選項")
                                Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppDesignSystem.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        if showAdvancedOptions {
                            // Task Type picker
                            HStack {
                                Text("任務類型")
                                    .font(AppDesignSystem.bodyFont)
                                Spacer()
                                Menu {
                                    ForEach(TaskType.allCases, id: \.self) { type in
                                        Button {
                                            taskType = type
                                        } label: {
                                            HStack {
                                                Image(systemName: type == .generic ? "checklist" :
                                                               type == .homework ? "book.closed" : "briefcase")
                                                    .frame(width: 16, height: 16)
                                                Text(type.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: taskType == .generic ? "checklist" :
                                                       taskType == .homework ? "book.closed" : "briefcase")
                                            .frame(width: 12, height: 12)
                                        Text(taskType.displayName)
                                            .font(AppDesignSystem.bodyFont)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            AddTaskOwnershipView(
                                selectedOrgId: $selectedOrgId,
                                assigneeUserId: $assigneeUserId,
                                assigneeOptions: $assigneeOptions,
                                orgViewModel: orgViewModel
                            )
                            
                            AddTaskTimeSettingsView(
                                estimatedHours: $estimatedHours,
                                hasPlannedDate: $hasPlannedDate,
                                plannedDate: $plannedDate,
                                reminderEnabled: $reminderEnabled,
                                reminderDate: $reminderDate,
                                hasDeadline: $hasDeadline,
                                deadline: $deadline
                            )

                            // Recurrence
                            VStack(alignment: .leading, spacing: 12) {
                                Text("重複設定")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                RecurrencePicker(rule: $recurrenceRule, endDate: $recurrenceEndDate, anchorDate: recurrenceAnchorDate)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard()

                            // Dependencies
                            VStack(alignment: .leading, spacing: 12) {
                                Text("前置依賴")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                if dependencyCandidates.isEmpty {
                                    Text("目前沒有其他未完成的任務可供選擇。")
                                        .font(AppDesignSystem.captionFont)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 4)
                                } else {
                                    ForEach(dependencyCandidates, id: \.id) { candidate in
                                        if let id = candidate.id {
                                            Toggle(isOn: Binding(
                                                get: { dependencySelections.contains(id) },
                                                set: { isOn in
                                                    if isOn {
                                                        // 檢查循環依賴
                                                        if !hasCircularDependency(newDependencyId: id) {
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
                                                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                                                    HStack(spacing: 8) {
                                                        if let deadline = candidate.deadlineAt {
                                                            Label(deadline.formatShort(), systemImage: "calendar")
                                                                .font(AppDesignSystem.captionFont)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        Label(candidate.category.displayName, systemImage: "square.grid.2x2")
                                                            .font(AppDesignSystem.captionFont)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }
                                            .toggleStyle(.switch)
                                        }
                                    }
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard()

                            // Subtasks section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("子任務")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                // Add subtask
                                HStack {
                                    TextField("新增子任務", text: $newSubtask)
                                        .textFieldStyle(.plain)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            addSubtask()
                                        }

                                    Button {
                                        addSubtask()
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(newSubtask.isEmpty ? .secondary : AppDesignSystem.accentColor)
                                    }
                                    .disabled(newSubtask.isEmpty)
                                }
                                .padding(AppDesignSystem.paddingMedium)
                                .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                                // Subtasks list
                                if !subtasks.isEmpty {
                                    VStack(spacing: 8) {
                                        ForEach(subtasks.indices, id: \.self) { index in
                                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                                Text(subtasks[index])
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Menu {
                                                    Button {
                                                        // Move up
                                                        if index > 0 {
                                                            subtasks.swapAt(index, index - 1)
                                                        }
                                                    } label: {
                                                        Label("上移", systemImage: "arrow.up")
                                                    }
                                                    .disabled(index == 0)

                                                    Button {
                                                        // Move down
                                                        if index < subtasks.count - 1 {
                                                            subtasks.swapAt(index, index + 1)
                                                        }
                                                    } label: {
                                                        Label("下移", systemImage: "arrow.down")
                                                    }
                                                    .disabled(index == subtasks.count - 1)

                                                    Button {
                                                        // Duplicate
                                                        subtasks.insert(subtasks[index] + " (複製)", at: index + 1)
                                                    } label: {
                                                        Label("複製", systemImage: "doc.on.doc")
                                                    }

                                                    Divider()

                                                    Button(role: .destructive) {
                                                        _Concurrency.Task {
                                                            guard deletingSubtaskIndex == nil else { return }
                                                            await MainActor.run { deletingSubtaskIndex = index }
                                                            // small delay to allow UI to show progress if needed
                                                            try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
                                                            subtasks.remove(at: index)
                                                            await MainActor.run { deletingSubtaskIndex = nil }
                                                        }
                                                    } label: {
                                                        Label("刪除", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.appSecondaryBackground.opacity(0.5))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard()

                            // Completion Percentage section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("預計完成度")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("初始完成百分比")
                                            .font(AppDesignSystem.bodyFont)
                                        Spacer()
                                        Text("\(completionPercentage)%")
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: .init(get: { Double(completionPercentage) }, set: { completionPercentage = Int($0) }), in: 0...100, step: 1)
                                        .tint(AppDesignSystem.accentColor)
                                }
                                .padding(AppDesignSystem.paddingMedium)
                                .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard()

                            // Tags section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("標籤")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)

                                // Add tag
                                ZStack(alignment: .topLeading) {
                                    HStack {
                                        TextField("新增標籤", text: $newTag)
                                            .textFieldStyle(.plain)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                addTag()
                                            }
                                            .onChange(of: newTag) {
                                                updateTagSuggestions()
                                            }

                                        Button {
                                            addTag()
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(newTag.isEmpty ? .secondary : AppDesignSystem.accentColor)
                                        }
                                        .disabled(newTag.isEmpty)
                                    }
                                    .padding(AppDesignSystem.paddingMedium)
                                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                                    // Tag suggestions
                                    if showTagSuggestions && !tagSuggestions.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(tagSuggestions.prefix(5), id: \.self) { suggestion in
                                                Button {
                                                    newTag = suggestion
                                                    addTag()
                                                } label: {
                                                    HStack {
                                                        Text(suggestion)
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                        Image(systemName: "plus.circle")
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                }
                                                .background(Color.appSecondaryBackground.opacity(0.9))
                                            }
                                        }
                                        .background(Color.appSecondaryBackground.opacity(0.95))
                                        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                                        .shadow(radius: 4)
                                        .offset(y: 60)
                                        .zIndex(1)
                                    }
                                }

                                // Tags list
                                if !tags.isEmpty {
                                    FlowLayout(spacing: 8) {
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
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard()
                        }
                    }
                    .padding(AppDesignSystem.paddingMedium)
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 
                        if !title.isEmpty || !description.isEmpty {
                            // 如果有輸入內容，可以顯示確認對話框
                            dismiss()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(title.isEmpty ? .secondary : AppDesignSystem.accentColor)
                    .disabled(title.isEmpty || isCreating)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("使用模板", systemImage: "doc.text")
                        }
                        
                        Button {
                            // 快速填充常用任務
                            fillQuickTemplate()
                        } label: {
                            Label("快速填充", systemImage: "bolt.fill")
                        }
                        
                        Divider()
                        
                        Button {
                            // 清除所有輸入
                            clearAllInputs()
                        } label: {
                            Label("清除全部", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .disabled(isCreating)
            .onAppear {
                _Concurrency.Task { 
                    await refreshAssigneeOptions()
                    await checkNotificationPermission()
                }
                normalizeReminderDate()
            }
            .onChange(of: selectedOrgId) {
                _Concurrency.Task { await refreshAssigneeOptions() }
            }
            .onChange(of: hasDeadline) {
                normalizeReminderDate()
            }
            .onChange(of: deadline) {
                normalizeReminderDate()
            }
            .onChange(of: reminderEnabled) { oldValue, enabled in
                if enabled {
                    _Concurrency.Task {
                        await requestNotificationPermissionIfNeeded()
                    }
                }
            }
        }
        .overlay {
            if isCreating {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("建立中...")
                        .padding()
                        .background(Material.thin)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .confirmationDialog("清除所有子任務？", isPresented: $showClearAllConfirmation) {
            Button("清除全部", role: .destructive) {
                subtasks.removeAll()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作會移除所有子任務，無法復原。")
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerView(selectedTemplate: $selectedTemplate)
                .onDisappear {
                    if let template = selectedTemplate {
                        applyTemplate(template)
                    }
                }
        }
        .alert("需要通知權限", isPresented: $showNotificationPermissionAlert) {
            Button("取消", role: .cancel) { }
            Button("前往設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("允許") {
                _Concurrency.Task {
                    await requestNotificationPermission()
                }
            }
        } message: {
            Text("為了及時提醒您任務，請允許通知權限。您可以在設定中隨時更改此權限。")
        }
    }

    private var recurrenceAnchorDate: Date {
        if hasPlannedDate {
            return plannedDate
        } else if hasDeadline {
            return deadline
        } else {
            return Date()
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60)) 分鐘"
        } else if hours == floor(hours) {
            return "\(Int(hours)) 小時"
        } else {
            return String(format: "%.1f 小時", hours)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
        showTagSuggestions = false
    }

    private func updateTagSuggestions() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            tagSuggestions = []
            showTagSuggestions = false
            return
        }

        // Get all existing tags from tasks
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        var existingTags = Set<String>()
        for task in allTasks {
            if let taskTags = task.tags {
                existingTags.formUnion(taskTags)
            }
        }

        // Filter suggestions based on input
        tagSuggestions = existingTags
            .filter { $0.lowercased().contains(trimmed) && !tags.contains($0) }
            .sorted()
        showTagSuggestions = !tagSuggestions.isEmpty
    }

    private func getAttachmentIcon(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "chart.bar.doc.horizontal"
        case "ppt", "pptx":
            return "chart.pie"
        case "jpg", "jpeg", "png", "gif":
            return "photo"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "wav", "m4a":
            return "music.note"
        default:
            return "doc"
        }
    }

    private func validateInputs() -> Bool {
        // Title is required
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ToastManager.shared.showToast(message: "請輸入任務標題", type: .warning)
            return false
        }

        // Title length limit
        if title.count > 100 {
            ToastManager.shared.showToast(message: "任務標題不能超過100個字符", type: .warning)
            return false
        }

        // Description length limit
        if description.count > 1000 {
            ToastManager.shared.showToast(message: "任務描述不能超過1000個字符", type: .warning)
            return false
        }

        // Estimated hours validation
        if estimatedHours < 0.1 || estimatedHours > 16 {
            ToastManager.shared.showToast(message: "預估時長必須在0.1到16小時之間", type: .warning)
            return false
        }

        // Deadline validation
        if hasDeadline && deadline <= Date() {
            ToastManager.shared.showToast(message: "截止日期必須在未來", type: .warning)
            return false
        }

        // Planned date validation
        if hasPlannedDate && plannedDate < Date().addingTimeInterval(-86400) {
            ToastManager.shared.showToast(message: "排程日期不能是過去的日期", type: .warning)
            return false
        }

        // Subtask validation
        for subtask in subtasks {
            if subtask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToastManager.shared.showToast(message: "子任務不能為空", type: .warning)
                return false
            }
            if subtask.count > 200 {
                ToastManager.shared.showToast(message: "子任務名稱不能超過200個字符", type: .warning)
                return false
            }
        }

        // Tag validation
        for tag in tags {
            if tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ToastManager.shared.showToast(message: "標籤不能為空", type: .warning)
                return false
            }
            if tag.count > 50 {
                ToastManager.shared.showToast(message: "標籤名稱不能超過50個字符", type: .warning)
                return false
            }
        }

        // Completion percentage validation
        if completionPercentage < 0 || completionPercentage > 100 {
            ToastManager.shared.showToast(message: "完成度必須在0-100之間", type: .warning)
            return false
        }

        return true
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            subtasks.append(trimmed)
        }
        newSubtask = ""
    }
    
    private var dependencyCandidates: [Task] {
        let tasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        return tasks
            .filter { $0.id != nil && !$0.isDone }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private func hasCircularDependency(newDependencyId: String) -> Bool {
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        
        // 檢查新依賴是否依賴於當前選擇的依賴（會形成循環）
        if let newDepTask = allTasks.first(where: { $0.id == newDependencyId }) {
            // 如果新依賴任務已經依賴於當前選擇的依賴，會形成循環
            for selectedDepId in dependencySelections {
                if newDepTask.dependsOnTaskIds.contains(selectedDepId) {
                    return true
                }
            }
            
            // 遞歸檢查：如果新依賴任務依賴的任務中，有任何一個依賴於當前選擇的依賴，也會形成循環
            for depId in newDepTask.dependsOnTaskIds {
                if hasCircularDependencyRecursive(checkTaskId: depId, allTasks: allTasks, visited: Set<String>(), selectedDependencies: dependencySelections) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func hasCircularDependencyRecursive(checkTaskId: String, allTasks: [Task], visited: Set<String>, selectedDependencies: Set<String>) -> Bool {
        // 防止無限遞歸
        if visited.contains(checkTaskId) {
            return false
        }

        var newVisited = visited
        newVisited.insert(checkTaskId)

        // 如果檢查的任務是當前選擇的依賴之一，形成循環
        if selectedDependencies.contains(checkTaskId) {
            return true
        }

        // 檢查該任務的依賴
        if let checkTask = allTasks.first(where: { $0.id == checkTaskId }) {
            for depId in checkTask.dependsOnTaskIds {
                if hasCircularDependencyRecursive(checkTaskId: depId, allTasks: allTasks, visited: newVisited, selectedDependencies: selectedDependencies) {
                    return true
                }
            }
        }

        return false
    }

    
    private func refreshAssigneeOptions() async {
        if let orgId = selectedOrgId {
            await loadOrgAssignees(orgId: orgId)
        } else {
            await loadPersonalAssignee()
        }
    }
    
    private func loadPersonalAssignee() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var profile: UserProfile? = viewModel.userProfile
        if profile == nil {
            do {
                profile = try await userService.fetchUserProfile(userId: uid)
            } catch {
                print("Error fetching user profile for assignee: \(error)")
            }
        }
        
        let option = AssigneeOption(id: uid, name: profile?.name ?? "我自己", detail: "個人任務")
        await MainActor.run {
            assigneeOptions = [option]
            if assigneeUserId == nil { assigneeUserId = uid }
        }
    }
    
    private func loadOrgAssignees(orgId: String) async {
        do {
            let memberships = try await organizationService.fetchOrganizationMembers(organizationId: orgId)
            let profiles = try await userService.fetchUserProfiles(userIds: memberships.map { $0.userId })
            
            let options = memberships.compactMap { membership -> AssigneeOption? in
                let name = profiles[membership.userId]?.name ?? "組織成員"
                return AssigneeOption(id: membership.userId, name: name, detail: "組織成員")
            }.sorted { $0.name < $1.name }
            
            await MainActor.run {
                assigneeOptions = options
                if let first = options.first, !options.contains(where: { $0.id == assigneeUserId }) {
                    assigneeUserId = first.id
                }
            }
        } catch {
            await MainActor.run {
                assigneeOptions = []
                let errorMessage = "載入組織成員失敗，請檢查網路連線。如持續失敗，請稍後重試。"
                ToastManager.shared.showToast(message: errorMessage, type: .error)
                AppLogger.shared.error("Failed to load organization members: \(error.localizedDescription)", error: error, category: .organizations)
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

    private func createTask() {
        _Concurrency.Task {
            // Avoid duplicate submissions while a request is running
            if await MainActor.run(body: { isCreating }) { return }

            // Validate before showing loading to prevent unnecessary UI lock
            guard validateInputs() else { return }

            let fallbackAssignee = assigneeUserId ?? Auth.auth().currentUser?.uid
            
            // 轉換子任務字符串為 Subtask 對象
            let subtaskObjects: [Subtask]? = subtasks.isEmpty ? nil : subtasks.enumerated().map { index, title in
                Subtask(title: title, isDone: false, sortOrder: index)
            }
            
            // 驗證依賴關係（防止循環依賴）
            let finalDependencies = Array(dependencySelections)
            if finalDependencies.contains(where: { hasCircularDependency(newDependencyId: $0) }) {
                ToastManager.shared.showToast(message: "無法保存：檢測到循環依賴", type: .error)
                return
            }

            await MainActor.run { isCreating = true }

            let success = await viewModel.createTaskAsync(
                title: title,
                description: description.isEmpty ? nil : description,
                category: category,
                priority: priority,
                deadline: hasDeadline ? deadline : nil,
                estimatedMinutes: Int(estimatedHours * 60),
                plannedDate: hasPlannedDate ? plannedDate : nil,
                isDateLocked: hasPlannedDate,
                sourceOrgId: selectedOrgId,
                assigneeUserIds: fallbackAssignee.map { [$0] },
                dependsOnTaskIds: finalDependencies,
                tags: tags,
                reminderAt: reminderEnabled ? reminderDate : nil,
                reminderEnabled: reminderEnabled,
                subtasks: subtaskObjects,
                completionPercentage: completionPercentage > 0 ? completionPercentage : nil,
                taskType: taskType,
                recurrence: recurrenceRule,
                recurrenceEndDate: recurrenceEndDate
            )

            await MainActor.run { isCreating = false }

            guard success else { return }

            // 如果啟用了提醒，調度本地通知（在後台執行）
            if reminderEnabled {
                _Concurrency.Task {
                    await scheduleReminderNotification()
                }
            }

            // 延遲關閉以顯示成功訊息
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    // MARK: - Notification Permission & Scheduling
    
    private func checkNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            notificationPermissionGranted = settings.authorizationStatus == .authorized
        }
    }
    
    private func requestNotificationPermissionIfNeeded() async {
        guard !notificationPermissionGranted else { return }
        
        let granted = await notificationService.requestAuthorization()
        await MainActor.run {
            notificationPermissionGranted = granted
            if !granted {
                reminderEnabled = false
                showNotificationPermissionAlert = true
            }
        }
    }
    
    private func requestNotificationPermission() async {
        isRequestingNotificationPermission = true
        let granted = await notificationService.requestAuthorization()
        await MainActor.run {
            notificationPermissionGranted = granted
            isRequestingNotificationPermission = false
            if granted {
                ToastManager.shared.showToast(message: "通知權限已啟用", type: .success)
            } else {
                ToastManager.shared.showToast(message: "通知權限被拒絕，提醒功能將無法使用", type: .warning)
                reminderEnabled = false
            }
        }
    }
    
    private func scheduleReminderNotification() async {
        guard reminderEnabled else { return }
        guard reminderDate > Date() else { return }
        
        // 注意：任務創建後，通知會通過TaskService在createTask方法中調度
        // 這裡只是記錄提醒已設定
        print("✅ 提醒已設定：\(reminderDate)")
    }
    
    // MARK: - Template Functions
    
    private func applyTemplate(_ template: TaskTemplate) {
        title = template.name
        if let desc = template.description {
            description = desc
        }
        category = template.category
        priority = template.priority
        if let minutes = template.estimatedMinutes {
            estimatedHours = Double(minutes) / 60.0
        }
        if let templateTags = template.tags {
            tags = templateTags
        }
        if let templateSubtasks = template.subtasks {
            subtasks = templateSubtasks.map { $0.title }
        }
        reminderEnabled = template.reminderEnabled
        
        ToastManager.shared.showToast(message: "已套用模板「\(template.name)」", type: .success)
    }
    
    private func fillQuickTemplate() {
        // 快速填充常用任務模板
        let quickTemplates: [(String, TaskCategory, TaskPriority, Double)] = [
            ("閱讀", .personal, .medium, 1.0),
            ("運動", .personal, .high, 0.5),
            ("購物", .personal, .low, 1.0),
            ("學習", .school, .high, 2.0),
            ("會議", .work, .high, 1.0)
        ]
        
        if let random = quickTemplates.randomElement() {
            title = random.0
            category = random.1
            priority = random.2
            estimatedHours = random.3
            ToastManager.shared.showToast(message: "已快速填充「\(random.0)」", type: .info)
        }
    }
    
    private func clearAllInputs() {
        title = ""
        description = ""
        category = .personal
        priority = .medium
        estimatedHours = 1.0
        hasDeadline = false
        deadline = Date().addingTimeInterval(86400)
        hasPlannedDate = false
        plannedDate = Date()
        subtasks = []
        newSubtask = ""
        completionPercentage = 0
        tags = []
        newTag = ""
        reminderEnabled = false
        reminderDate = Date().addingTimeInterval(3600)
        dependencySelections = []
        selectedOrgId = nil
        assigneeUserId = nil
        
        ToastManager.shared.showToast(message: "已清除所有輸入", type: .info)
    }
}

