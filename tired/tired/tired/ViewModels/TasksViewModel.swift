import Foundation
import Combine
import FirebaseAuth

/// 任務視圖的ViewModel
class TasksViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var weekTasks: [Task] = []
    @Published var backlogTasks: [Task] = []
    @Published var isLoading = true
    @Published var selectedCategory: TaskCategory?
    @Published var sortOption: TaskSortOption = .deadline
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?
    @Published var isCalendarAuthorized = false

    private let taskService = TaskService()
    private let autoPlanService = AutoPlanService()
    private let permissionService = PermissionService()
    private let userService = UserService()
    private let calendarService = CalendarService()
    private var cancellables = Set<AnyCancellable>()
    private var loadingCounter = 0 {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = self?.loadingCounter ?? 0 > 0
            }
        }
    }

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        setupSubscriptions()
        _Concurrency.Task {
            await loadUserProfile()
            await checkCalendarAuthorization()
        }
    }

    func setupSubscriptions() {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            isLoading = false
            return
        }

        // 今天的任务
        loadingCounter += 1
        taskService.fetchTodayTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.loadingCounter -= 1
                    if case .failure(let error) = completion {
                        print("❌ Error fetching today tasks: \(error)")
                        self?.errorMessage = "載入今天的任務失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.todayTasks = tasks
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)

        // 本周的任务
        loadingCounter += 1
        taskService.fetchWeekTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.loadingCounter -= 1
                    if case .failure(let error) = completion {
                        print("❌ Error fetching week tasks: \(error)")
                        self?.errorMessage = "載入本周的任務失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.weekTasks = tasks
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)

        // Backlog任务
        loadingCounter += 1
        taskService.fetchBacklogTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.loadingCounter -= 1
                    if case .failure(let error) = completion {
                        print("❌ Error fetching backlog tasks: \(error)")
                        self?.errorMessage = "載入未排程的任務失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.backlogTasks = tasks
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    @discardableResult
    private func loadUserProfile() async -> UserProfile? {
        guard let userId = userId else { return nil }
        
        do {
            let profile = try await userService.fetchUserProfile(userId: userId)
            await MainActor.run {
                self.userProfile = profile
            }
            return profile
        } catch {
            print("❌ Error fetching user profile: \(error)")
            return nil
        }
    }

    // MARK: - Actions

    func toggleTaskDone(task: Task) {
        guard let id = task.id, let currentUserId = userId else { return }

        _Concurrency.Task {
            do {
                var hasPermission = false
                if let orgId = task.sourceOrgId {
                    hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageAllOrgTasks)
                } else {
                    // Personal task: only author can toggle completion
                    hasPermission = task.userId == currentUserId
                }

                guard hasPermission else {
                    ToastManager.shared.showToast(message: "您沒有權限變更此任務的完成狀態。", type: .error)
                    return
                }

                try await taskService.toggleTaskDone(id: id, isDone: !task.isDone)
                ToastManager.shared.showToast(message: "任務狀態更新成功！", type: .success)
            } catch {
                print("❌ Error toggling task: \(error)")
                ToastManager.shared.showToast(message: "任務狀態更新失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    /// 判斷當前用戶是否可以修改某個任務的完成狀態
    func canToggleDone(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageAllOrgTasks)
            } catch {
                print("Error checking toggle done permission for organization task: \(error)")
                return false
            }
        } else {
            // Personal task: only author can toggle completion
            return task.userId == currentUserId
        }
    }

    func deleteTask(task: Task) {
        guard let id = task.id, let currentUserId = userId else { return }

        _Concurrency.Task {
            do {
                var hasPermission = false
                if let orgId = task.sourceOrgId {
                    // Check if user has permission to delete any task in this organization
                    hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyTaskInOrg)
                } else {
                    // If it's a personal task, only author can delete
                    hasPermission = task.userId == currentUserId
                }

                guard hasPermission else {
                    ToastManager.shared.showToast(message: "您沒有權限刪除此任務。", type: .error)
                    return
                }

                try await taskService.deleteTask(id: id)
                ToastManager.shared.showToast(message: "任務已刪除！", type: .success)
            } catch {
                print("❌ Error deleting task: \(error)")
                ToastManager.shared.showToast(message: "刪除任務失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }

    func createTask(
        title: String,
        description: String?,
        category: TaskCategory,
        priority: TaskPriority,
        deadline: Date?,
        estimatedMinutes: Int?,
        plannedDate: Date?,
        isDateLocked: Bool,
        sourceOrgId: String?
    ) {
        guard let userId = userId else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            return
        }

        let task = Task(
            userId: userId,
            title: title,
            description: description,
            category: category,
            priority: priority,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes,
            plannedDate: plannedDate,
            isDateLocked: isDateLocked,
            sourceOrgId: sourceOrgId
        )

        _Concurrency.Task {
            do {
                try await taskService.createTask(task)
                ToastManager.shared.showToast(message: "任務創建成功！", type: .success)
            } catch {
                print("❌ Error creating task: \(error)")
                ToastManager.shared.showToast(message: "任務創建失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }

    func updateTask(_ task: Task) {
        guard let currentUserId = userId else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            return
        }

        _Concurrency.Task {
            do {
                var hasPermission = false
                if let orgId = task.sourceOrgId {
                    hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.editAnyTaskInOrg)
                } else {
                    // Personal task: only author can edit
                    hasPermission = task.userId == currentUserId
                }

                guard hasPermission else {
                    ToastManager.shared.showToast(message: "您沒有權限編輯此任務。", type: .error)
                    return
                }

                try await taskService.updateTask(task)
                ToastManager.shared.showToast(message: "任務更新成功！", type: .success)
            } catch {
                print("❌ Error updating task: \(error)")
                ToastManager.shared.showToast(message: "任務更新失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    /// 判斷當前用戶是否可以編輯某個任務
    func canEdit(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.editAnyTaskInOrg)
            } catch {
                print("Error checking edit permission for organization task: \(error)")
                return false
            }
        } else {
            // Personal task: only author can edit
            return task.userId == currentUserId
        }
    }

    // MARK: - Calendar Integration

    @MainActor
    func checkCalendarAuthorization() {
        isCalendarAuthorized = calendarService.isAuthorized
    }

    @MainActor
    func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        isCalendarAuthorized = granted
        if granted {
            ToastManager.shared.showToast(message: "行事曆已連接！", type: .success)
        } else {
            ToastManager.shared.showToast(message: "行事曆權限被拒絕。", type: .warning)
        }
    }
    
    // MARK: - Auto Plan

    func runAutoplan(weeklyCapacityOverride: Int? = nil, dailyCapacityOverride: Int? = nil) {
        _Concurrency.Task {
            await MainActor.run { loadingCounter += 1 }
            defer {
                await MainActor.run { loadingCounter -= 1 }
            }

            // Fetch busy blocks from calendar if authorized
            var busyBlocks: [BusyTimeBlock] = []
            if await MainActor.run(body: { self.isCalendarAuthorized }) {
                busyBlocks = await calendarService.fetchBusyTimeBlocks(forNextDays: 14)
            }

            // 获取所有任务
            let allTasks = await MainActor.run {
                todayTasks + weekTasks + backlogTasks
            }

            // 运行autoplan
            let profile = await loadUserProfile() ?? userProfile
            let weeklyCapacity = weeklyCapacityOverride
                ?? profile?.weeklyCapacityMinutes
                ?? 600
            let dailyCapacity = dailyCapacityOverride ?? profile?.dailyCapacityMinutes
            let workdays = dailyCapacity != nil ? 7 : 5

            let options = AutoPlanService.AutoPlanOptions(
                weeklyCapacityMinutes: weeklyCapacity,
                dailyCapacityMinutes: dailyCapacity,
                workdaysInWeek: workdays
            )
            let (updatedTasks, scheduledTaskCount) = autoPlanService.autoplanWeek(
                tasks: allTasks,
                busyBlocks: busyBlocks,
                options: options
            )

            // 批量更新
            do {
                try await taskService.batchUpdateTasks(updatedTasks)
                if scheduledTaskCount > 0 {
                    ToastManager.shared.showToast(message: "自動排程完成！成功排程 \(scheduledTaskCount) 個任務。", type: .success)
                } else {
                    ToastManager.shared.showToast(message: "自動排程完成！沒有新的任務被排程。", type: .info)
                }
            } catch {
                print("❌ Error running autoplan: \(error)")
                ToastManager.shared.showToast(message: "自動排程失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }

    // MARK: - Task Comments

    /// 新增評論並回傳新評論以便更新本地 UI
    @discardableResult
    func addComment(to task: Task, content: String) async -> TaskComment? {
        guard let currentUserId = userId, task.id != nil else {
            ToastManager.shared.showToast(message: "用戶未登入或任務ID無效。", type: .error)
            return nil
        }
        guard !content.isEmpty else {
            ToastManager.shared.showToast(message: "評論內容不能為空。", type: .warning)
            return nil
        }

        // RBAC Check for adding comment
        if let orgId = task.sourceOrgId {
            do {
                let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.createTaskCommentInOrg)
                guard hasPermission else {
                    ToastManager.shared.showToast(message: "您沒有權限在此任務下發表評論。", type: .error)
                    return nil
                }
            } catch {
                ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
                return nil
            }
        } // No RBAC for personal tasks - any user can comment on their own tasks

        var updatedTask = task
        let newComment = TaskComment(authorUserId: currentUserId, content: content)
        if updatedTask.comments == nil {
            updatedTask.comments = []
        }
        updatedTask.comments?.append(newComment)
        updatedTask.updatedAt = Date()

        do {
            try await taskService.updateTask(updatedTask) // Update the task in Firestore
            ToastManager.shared.showToast(message: "評論已新增！", type: .success)
            return newComment
        } catch {
            print("❌ Error adding comment: \(error)")
            ToastManager.shared.showToast(message: "新增評論失敗: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    /// 刪除評論並回傳是否成功，便於 UI 同步
    func deleteComment(from task: Task, comment: TaskComment) async -> Bool {
        guard let currentUserId = userId, task.id != nil, let commentId = comment.id else {
            ToastManager.shared.showToast(message: "用戶未登入或任務/評論ID無效。", type: .error)
            return false
        }

        // RBAC Check for deleting comment
        do {
            var hasPermission = false
            if let orgId = task.sourceOrgId {
                hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyTaskCommentInOrg)
                // If not 'deleteAny', check if it's their own comment and they have 'deleteOwnTaskComment'
                if !hasPermission && comment.authorUserId == currentUserId {
                    hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteOwnTaskComment)
                }
            } else {
                // Personal task: only author of the comment can delete their own comment
                hasPermission = comment.authorUserId == currentUserId
            }

            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限刪除此評論。", type: .error)
                return false
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return false
        }
        
        var updatedTask = task
        updatedTask.comments?.removeAll(where: { $0.id == commentId })
        updatedTask.updatedAt = Date()

        do {
            try await taskService.updateTask(updatedTask) // Update the task in Firestore
            ToastManager.shared.showToast(message: "評論已刪除！", type: .success)
            return true
        } catch {
            print("❌ Error deleting comment: \(error)")
            ToastManager.shared.showToast(message: "刪除評論失敗: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    func canAddComment(to task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.createTaskCommentInOrg)
            } catch {
                print("Error checking add comment permission: \(error)")
                return false
            }
        } else {
            // Personal task: any authenticated user can comment on their own tasks
            return true
        }
    }
    
    /// 判斷當前用戶是否可以刪除某個任務
    func canDelete(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            do {
                return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.deleteAnyTaskInOrg)
            } catch {
                print("Error checking delete permission for organization task: \(error)")
                return false
            }
        } else {
            // Personal task: only author can delete
            return task.userId == currentUserId
        }
    }

    // MARK: - Filter & Sort

    func filteredTasks(_ tasks: [Task]) -> [Task] {
        var filtered = tasks

        // 篩選分類
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }

        // 排序
        return sortTasks(filtered)
    }

    private func sortTasks(_ tasks: [Task]) -> [Task] {
        switch sortOption {
        case .deadline:
            return tasks.sorted { t1, t2 in
                // 有截止時間的優先，然後按時間排序
                if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                    return d1 < d2
                }
                if t1.deadlineAt != nil { return true }
                if t2.deadlineAt != nil { return false }
                return t1.createdAt < t2.createdAt
            }
        case .priority:
            return tasks.sorted { t1, t2 in
                if t1.priority != t2.priority {
                    return t1.priority.rawValue > t2.priority.rawValue
                }
                return t1.createdAt < t2.createdAt
            }
        case .category:
            return tasks.sorted { t1, t2 in
                if t1.category != t2.category {
                    return t1.category.rawValue < t2.category.rawValue
                }
                return t1.createdAt < t2.createdAt
            }
        case .created:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .urgency:
            // 使用緊急程度分數排序（分數越高越緊急）
            return tasks.sorted { t1, t2 in
                let score1 = t1.urgencyScore
                let score2 = t2.urgencyScore
                if score1 != score2 {
                    return score1 > score2
                }
                // 同分則按截止日期排序
                if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                    return d1 < d2
                }
                return t1.createdAt < t2.createdAt
            }
        }
    }

    // MARK: - Week Statistics

    func weeklyStatistics() -> [(day: Date, duration: Int)] {
        let weekStart = Date.startOfWeek()
        let days = Date.daysOfWeek(startingFrom: weekStart)

        return days.map { day in
            let duration = autoPlanService.calculateDailyDuration(tasks: weekTasks, for: day)
            return (day, duration)
        }
    }
}
