import Foundation
import Combine
import FirebaseAuth
import SwiftUI

/// 任務視圖的ViewModel
@MainActor
class TasksViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var weekTasks: [Task] = []
    @Published var backlogTasks: [Task] = []
    @Published var isLoading = true
    @Published var selectedCategory: TaskCategory?
    @Published var selectedOrganizationId: String? = nil // 組織篩選
    @Published var userOrganizations: [Organization] = [] // 用戶的組織列表
    @Published var sortOption: TaskSortOption = .deadline
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?
    @Published var isCalendarAuthorized = false
    @Published var lastDeletedTask: Task? // 用於撤銷刪除
    @Published var showUndoOption = false
    @Published var timeConflicts: [TaskConflict] = []
    
    // 成就系統
    @Published var showCelebration = false
    @Published var latestAchievement: TaskAchievement?
    @Published var completedTasksCount: Int = 0

    private let taskService = TaskService()
    private let autoPlanService = AutoPlanService()
    private let permissionService = PermissionService()
    private let userService = UserService()
    private let calendarService = CalendarService()
    private let dependencyService = TaskDependencyService()
    private let conflictDetector = TaskConflictDetector()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()
    private var loadingCounter = 0 {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = self?.loadingCounter ?? 0 > 0
            }
        }
    }
    private var hasReceivedInitialData: Set<String> = [] // 追蹤哪些數據源已收到初始數據

    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private func isOwnerOrAssignee(_ task: Task, currentUserId: String) -> Bool {
        task.userId == currentUserId || (task.assigneeUserIds?.contains(currentUserId) ?? false)
    }
    
    private func hasOrgPermission(_ orgId: String, permissions: [String]) async -> Bool {
        for permission in permissions {
            if (try? await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: permission)) == true {
                return true
            }
        }
        return false
    }

    init() {
        setupSubscriptions()
        setupOrganizationSubscription()
        _Concurrency.Task {
            await loadUserProfile()
            checkCalendarAuthorization()
        }
    }
    
    /// 訂閱用戶的組織列表
    private func setupOrganizationSubscription() {
        guard let userId = userId else { return }
        
        organizationService.fetchUserOrganizations(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching user organizations: \(error)")
                    }
                },
                receiveValue: { [weak self] memberships in
                    self?.userOrganizations = memberships.compactMap { $0.organization }
                }
            )
            .store(in: &cancellables)
    }

    func setupSubscriptions() {
        // 清空舊的訂閱以避免重複監聽
        cancellables.removeAll()
        loadingCounter = 0
        hasReceivedInitialData.removeAll()
        
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
                    // 實時監聽器通常不會完成，只有在錯誤時才會
                    if case .failure(let error) = completion {
                        print("❌ Error fetching today tasks: \(error)")
                        self?.errorMessage = "載入今天的任務失敗：\(error.localizedDescription)"
                        // 即使出錯也要減少計數器
                        if !(self?.hasReceivedInitialData.contains("today") ?? false) {
                            self?.loadingCounter -= 1
                        }
                    }
                },
                receiveValue: { [weak self] tasks in
                    guard let self = self else { return }
                    // 第一次收到數據時減少計數器
                    if !self.hasReceivedInitialData.contains("today") {
                        self.hasReceivedInitialData.insert("today")
                        self.loadingCounter -= 1
                    }
                    self.todayTasks = tasks
                    self.errorMessage = nil
                    self.checkForConflicts()
                }
            )
            .store(in: &cancellables)

        // 本周的任务
        loadingCounter += 1
        taskService.fetchWeekTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching week tasks: \(error)")
                        self?.errorMessage = "載入本周的任務失敗：\(error.localizedDescription)"
                        if !(self?.hasReceivedInitialData.contains("week") ?? false) {
                            self?.loadingCounter -= 1
                        }
                    }
                },
                receiveValue: { [weak self] tasks in
                    guard let self = self else { return }
                    if !self.hasReceivedInitialData.contains("week") {
                        self.hasReceivedInitialData.insert("week")
                        self.loadingCounter -= 1
                    }
                    self.weekTasks = tasks
                    self.errorMessage = nil
                    self.checkForConflicts()
                }
            )
            .store(in: &cancellables)

        // Backlog任务
        loadingCounter += 1
        taskService.fetchBacklogTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching backlog tasks: \(error)")
                        self?.errorMessage = "載入未排程的任務失敗：\(error.localizedDescription)"
                        if !(self?.hasReceivedInitialData.contains("backlog") ?? false) {
                            self?.loadingCounter -= 1
                        }
                    }
                },
                receiveValue: { [weak self] tasks in
                    guard let self = self else { return }
                    if !self.hasReceivedInitialData.contains("backlog") {
                        self.hasReceivedInitialData.insert("backlog")
                        self.loadingCounter -= 1
                    }
                    self.backlogTasks = tasks
                    self.errorMessage = nil
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

    // MARK: - Undo
    
    func undoDelete() {
        guard let task = lastDeletedTask else { return }
        
        _Concurrency.Task {
            do {
                try await taskService.restoreTask(task)
                await MainActor.run {
                    self.showUndoOption = false
                    self.lastDeletedTask = nil
                    ToastManager.shared.showToast(message: "任務已還原", type: .success)
                }
            } catch {
                print("❌ Error restoring task: \(error)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "還原任務失敗", type: .error)
                }
            }
        }
    }


    func checkForConflicts() {
        let allActiveTasks = todayTasks + weekTasks
        // 檢測本週範圍內的衝突
        self.timeConflicts = conflictDetector.detectWeeklyConflicts(tasks: allActiveTasks)
    }

    func getConflictDescription(_ conflict: TaskConflict) -> String {
        return conflict.description
    }

    // MARK: - Actions

    func toggleTaskDone(task: Task) {
        guard let id = task.id, let currentUserId = userId else { return }

        _Concurrency.Task {
            do {
                if !task.isDone {
                    let allTasks = await MainActor.run { self.todayTasks + self.weekTasks + self.backlogTasks }
                    let canFinish = dependencyService.canStartTask(task, allTasks: allTasks)
                    guard canFinish else {
                        ToastManager.shared.showToast(message: "請先完成所有前置任務，再標記此任務完成。", type: .warning)
                        return
                    }
                }
                
                let isOwnerOrAssigned = isOwnerOrAssignee(task, currentUserId: currentUserId)
                var hasPermission = isOwnerOrAssigned
                if let orgId = task.sourceOrgId {
                    // Org task: assignee/作者可完成；或具備管理/編輯任務權限
                    let orgPermission = await hasOrgPermission(orgId, permissions: [
                        AppPermissions.manageAllOrgTasks,
                        AppPermissions.editAnyTaskInOrg
                    ])
                    hasPermission = isOwnerOrAssigned || orgPermission
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

    /// 非同步版本，回傳是否操作成功，供 UI 呼叫者等待並處理狀態
    @discardableResult
    func toggleTaskDoneAsync(task: Task) async -> Bool {
        guard let id = task.id, let currentUserId = userId else { return false }

        do {
            let isMarkingComplete = !task.isDone
            
            if isMarkingComplete {
                let allTasks = await MainActor.run { self.todayTasks + self.weekTasks + self.backlogTasks }
                let canFinish = dependencyService.canStartTask(task, allTasks: allTasks)
                guard canFinish else {
                    // 找出未完成的依賴任務
                    let incompleteDeps = task.dependsOnTaskIds.compactMap { depId -> Task? in
                        allTasks.first { $0.id == depId && !$0.isDone }
                    }
                    
                    if !incompleteDeps.isEmpty {
                        let depNames = incompleteDeps.prefix(2).map { $0.title }.joined(separator: "、")
                        let message = incompleteDeps.count > 2
                            ? "請先完成「\(depNames)」等 \(incompleteDeps.count) 個前置任務"
                            : "請先完成「\(depNames)」"
                        ToastManager.shared.showToast(message: message, type: .warning)
                    } else {
                        ToastManager.shared.showToast(message: "請先完成所有前置任務，再標記此任務完成。", type: .warning)
                    }
                    return false
                }
            }

            let isOwnerOrAssigned = isOwnerOrAssignee(task, currentUserId: currentUserId)
            var hasPermission = isOwnerOrAssigned
            if let orgId = task.sourceOrgId {
                let orgPermission = await hasOrgPermission(orgId, permissions: [
                    AppPermissions.manageAllOrgTasks,
                    AppPermissions.editAnyTaskInOrg
                ])
                hasPermission = isOwnerOrAssigned || orgPermission
            }

            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限變更此任務的完成狀態。", type: .error)
                return false
            }

            // 如果是標記完成，使用完整的完成流程（包含成就檢查）
            if isMarkingComplete {
                let result = try await taskService.completeTask(taskId: id, userId: currentUserId)
                
                // 檢查解鎖的任務
                let allTasks = await MainActor.run { self.todayTasks + self.weekTasks + self.backlogTasks }
                let unlockedTasks = dependencyService.getUnlockedTasks(id, allTasks: allTasks)
                
                await MainActor.run {
                    completedTasksCount += 1
                    
                    // 顯示解鎖任務通知
                    if !unlockedTasks.isEmpty {
                        let taskNames = unlockedTasks.prefix(3).map { $0.title }.joined(separator: "、")
                        let message = unlockedTasks.count > 3
                            ? "🔓 \(taskNames) 等 \(unlockedTasks.count) 個任務已解鎖！"
                            : "🔓 \(taskNames) 已解鎖！"
                        ToastManager.shared.showToast(message: message, type: .success)
                    }
                    
                    // 如果有新成就，顯示慶祝動畫
                    if let achievement = result.achievement {
                        latestAchievement = achievement
                        showCelebration = true
                        ToastManager.shared.showToast(message: "🎉 獲得成就：\(achievement.title)", type: .success)
                    } else {
                        // 普通完成提示
                        showCompletionFeedback()
                    }
                }
            } else {
                // 標記為未完成
                try await taskService.toggleTaskDone(id: id, isDone: false)
                ToastManager.shared.showToast(message: "任務已標記為未完成", type: .info)
            }
            
            return true
        } catch {
            print("❌ Error toggling task async: \(error)")
            ToastManager.shared.showToast(message: "任務狀態更新失敗：\(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    /// 顯示任務完成的鼓勵反饋
    private func showCompletionFeedback() {
        let messages = [
            "做得好！繼續保持！ 💪",
            "太棒了！又完成一個！ ✨",
            "任務完成！你真棒！ 🌟",
            "完美！繼續前進！ 🚀",
            "成功！休息一下吧！ ☕️"
        ]
        let randomMessage = messages.randomElement() ?? "任務完成！"
        ToastManager.shared.showToast(message: randomMessage, type: .success)
    }
    
    /// 關閉慶祝動畫
    func dismissCelebration() {
        showCelebration = false
        latestAchievement = nil
    }
    
    /// 判斷當前用戶是否可以修改某個任務的完成狀態
    func canToggleDone(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            let orgPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.editAnyTaskInOrg
            ])
            return orgPermission || isOwnerOrAssignee(task, currentUserId: currentUserId)
        } else {
            // Personal task: author or assignee can toggle completion
            return isOwnerOrAssignee(task, currentUserId: currentUserId)
        }
    }

    func deleteTask(task: Task) {
        _Concurrency.Task { _ = await deleteTaskAsync(task: task) }
    }

    /// 非同步刪除，回傳是否成功，方便 UI 顯示狀態
    @discardableResult
    func deleteTaskAsync(task: Task) async -> Bool {
        guard let id = task.id, let currentUserId = userId else {
            await MainActor.run { ToastManager.shared.showToast(message: "無法刪除：缺少用戶或任務資訊", type: .error) }
            return false
        }

        do {
            var hasPermission = false
            if let orgId = task.sourceOrgId {
                // Org task: 作者或具備刪除/管理權限者可刪
                let orgPermission = await hasOrgPermission(orgId, permissions: [
                    AppPermissions.manageAllOrgTasks,
                    AppPermissions.deleteAnyTaskInOrg
                ])
                hasPermission = orgPermission || task.userId == currentUserId
            } else {
                // If it's a personal task, only author can delete
                hasPermission = task.userId == currentUserId
            }

            guard hasPermission else {
                await MainActor.run { ToastManager.shared.showToast(message: "您沒有權限刪除此任務。", type: .error) }
                return false
            }

            try await taskService.deleteTask(id: id)
            
            await MainActor.run { 
                self.lastDeletedTask = task
                self.showUndoOption = true
                ToastManager.shared.showToast(message: "任務已刪除", type: .info) 
                
                // 3秒後自動隱藏撤銷選項
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    if self.showUndoOption {
                        self.showUndoOption = false
                        self.lastDeletedTask = nil
                    }
                }
            }
            return true
        } catch {
            print("❌ Error deleting task: \(error)")
            await MainActor.run { ToastManager.shared.showToast(message: "刪除任務失敗：\(error.localizedDescription)", type: .error) }
            return false
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
        sourceOrgId: String?,
        assigneeUserIds: [String]? = nil,
        dependsOnTaskIds: [String] = [],
        tags: [String] = [],
        reminderAt: Date? = nil,
        reminderEnabled: Bool = false,
        subtasks: [Subtask]? = nil,
        completionPercentage: Int? = nil,
        taskType: TaskType = .generic
    ) {
        guard let userId = userId else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            return
        }

        let task = Task(
            userId: userId,
            sourceOrgId: sourceOrgId,
            sourceAppInstanceId: nil,
            sourceType: sourceOrgId == nil ? .manual : .orgTask,
            taskType: taskType,
            title: title,
            description: description,
            assigneeUserIds: assigneeUserIds ?? [userId],
            category: category,
            priority: priority,
            tags: tags.isEmpty ? nil : tags,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes,
            plannedDate: plannedDate,
            plannedStartTime: nil,
            isDateLocked: isDateLocked,
            completionPercentage: completionPercentage,
            subtasks: subtasks,
            reminderAt: reminderAt,
            reminderEnabled: reminderEnabled,
            dependsOnTaskIds: dependsOnTaskIds
        )

        _Concurrency.Task {
            do {
                _ = try await taskService.createTask(task)
                ToastManager.shared.showToast(message: "任務創建成功！", type: .success)
            } catch {
                print("❌ Error creating task: \(error)")
                ToastManager.shared.showToast(message: "任務創建失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }

    /// 非同步版本，會回傳是否創建成功，供 UI 呼叫者決定是否關閉視窗
    @discardableResult
    func createTaskAsync(
        title: String,
        description: String?,
        category: TaskCategory,
        priority: TaskPriority,
        deadline: Date?,
        estimatedMinutes: Int?,
        plannedDate: Date?,
        isDateLocked: Bool,
        sourceOrgId: String?,
        assigneeUserIds: [String]? = nil,
        dependsOnTaskIds: [String] = [],
        tags: [String] = [],
        reminderAt: Date? = nil,
        reminderEnabled: Bool = false,
        subtasks: [Subtask]? = nil,
        completionPercentage: Int? = nil,
        taskType: TaskType = .generic,
        recurrence: RecurrenceRule? = nil,
        recurrenceEndDate: Date? = nil
    ) async -> Bool {
        guard let userId = userId else {
            await MainActor.run { ToastManager.shared.showToast(message: "用戶未登入", type: .error) }
            return false
        }

        // Handle Recurring Task Creation
        if let rule = recurrence {
            let recurringTask = RecurringTask(
                userId: userId,
                title: title,
                description: description,
                category: category,
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                recurrenceRule: rule,
                startDate: plannedDate ?? Date(),
                endDate: recurrenceEndDate
            )
            
            do {
                try await RecurringTaskService.shared.createRecurringTask(recurringTask)
                await MainActor.run { ToastManager.shared.showToast(message: "週期任務創建成功！", type: .success) }
                return true
            } catch {
                print("❌ Error creating recurring task: \(error)")
                await MainActor.run { ToastManager.shared.showToast(message: "創建失敗：\(error.localizedDescription)", type: .error) }
                return false
            }
        }

        let task = Task(
            userId: userId,
            sourceOrgId: sourceOrgId,
            sourceAppInstanceId: nil,
            sourceType: sourceOrgId == nil ? .manual : .orgTask,
            taskType: taskType,
            title: title,
            description: description,
            assigneeUserIds: assigneeUserIds ?? [userId],
            category: category,
            priority: priority,
            tags: tags.isEmpty ? nil : tags,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes,
            plannedDate: plannedDate,
            plannedStartTime: nil,
            isDateLocked: isDateLocked,
            completionPercentage: completionPercentage,
            subtasks: subtasks,
            reminderAt: reminderAt,
            reminderEnabled: reminderEnabled,
            dependsOnTaskIds: dependsOnTaskIds
        )

        do {
            _ = try await taskService.createTask(task)
            await MainActor.run { ToastManager.shared.showToast(message: "任務創建成功！", type: .success) }
            return true
        } catch {
            print("❌ Error creating task async: \(error)")
            await MainActor.run { ToastManager.shared.showToast(message: "任務創建失敗：\(error.localizedDescription)", type: .error) }
            return false
        }
    }

    func updateTask(_ task: Task) {
        _Concurrency.Task { _ = await updateTaskAsync(task) }
    }

    /// 非同步更新，方便在表單中顯示 loading / 錯誤
    @discardableResult
    func updateTaskAsync(_ task: Task) async -> Bool {
        guard let currentUserId = userId else {
            await MainActor.run { ToastManager.shared.showToast(message: "用戶未登入", type: .error) }
            return false
        }

        do {
            var hasPermission = false
            if let orgId = task.sourceOrgId {
                let orgPermission = await hasOrgPermission(orgId, permissions: [
                    AppPermissions.manageAllOrgTasks,
                    AppPermissions.editAnyTaskInOrg
                ])
                hasPermission = orgPermission || isOwnerOrAssignee(task, currentUserId: currentUserId)
            } else {
                // Personal task: only author or assignee can edit
                hasPermission = isOwnerOrAssignee(task, currentUserId: currentUserId)
            }

            guard hasPermission else {
                await MainActor.run { ToastManager.shared.showToast(message: "您沒有權限編輯此任務。", type: .error) }
                return false
            }

            try await taskService.updateTask(task)
            await MainActor.run { ToastManager.shared.showToast(message: "任務更新成功！", type: .success) }
            return true
        } catch {
            print("❌ Error updating task: \(error)")
            await MainActor.run { ToastManager.shared.showToast(message: "任務更新失敗：\(error.localizedDescription)", type: .error) }
            return false
        }
    }
    
    /// 判斷當前用戶是否可以編輯某個任務
    func canEdit(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            let orgPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.editAnyTaskInOrg
            ])
            return orgPermission || isOwnerOrAssignee(task, currentUserId: currentUserId)
        } else {
            // Personal task: only author or assignee can edit
            return isOwnerOrAssignee(task, currentUserId: currentUserId)
        }
    }

    // MARK: - Calendar Integration

    
    func checkCalendarAuthorization() {
        isCalendarAuthorized = calendarService.isAuthorized
    }

    
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
                _Concurrency.Task {
                    await MainActor.run { loadingCounter -= 1 }
                }
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

        // --- Mention Logic ---
        let (cleanedContent, mentionedUsernames) = parseMentions(from: content)
        var mentionedUserIds: [String] = []
        if !mentionedUsernames.isEmpty, let orgId = task.sourceOrgId {
             // In a real implementation, you would fetch user IDs for the usernames
             // This might involve a new function in UserService like `fetchUserIds(for usernames: [String])`
             // For now, we'll simulate this by assuming the username is the user ID for simplicity.
            mentionedUserIds = await userService.fetchUserIds(forUsernames: mentionedUsernames, in: orgId)
        }
        // --- End Mention Logic ---

        // RBAC Check for adding comment
        var canComment = false
        if let orgId = task.sourceOrgId {
            let orgPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.createTaskCommentInOrg
            ])
            canComment = orgPermission || isOwnerOrAssignee(task, currentUserId: currentUserId)
        } else {
            canComment = isOwnerOrAssignee(task, currentUserId: currentUserId)
        }

        guard canComment else {
            ToastManager.shared.showToast(message: "您沒有權限在此任務下發表評論。", type: .error)
            return nil
        }

        var updatedTask = task
        let newComment = TaskComment(
            authorUserId: currentUserId,
            content: cleanedContent,
            mentionedUserIds: mentionedUserIds.isEmpty ? nil : mentionedUserIds
        )
        if updatedTask.comments == nil {
            updatedTask.comments = []
        }
        updatedTask.comments?.append(newComment)
        updatedTask.updatedAt = Date()

        do {
            try await taskService.updateTask(updatedTask) // Update the task in Firestore
            ToastManager.shared.showToast(message: "評論已新增！", type: .success)
            // The Firebase Function for notifications will be triggered by this update
            return newComment
        } catch {
            print("❌ Error adding comment: \(error)")
            ToastManager.shared.showToast(message: "新增評論失敗: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Parses a string for @mentions.
    /// - Returns: A tuple containing the cleaned string and an array of found usernames.
    private func parseMentions(from text: String) -> (cleanedContent: String, usernames: [String]) {
        // This is a simplified regex. A more robust solution would handle more edge cases.
        let pattern = "@(\\w+)"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let usernames = matches.map { match -> String in
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range])
        }
        
        // For now, we don't clean the content, but you could replace @username with a special token if needed.
        return (text, usernames)
    }

    /// 刪除評論並回傳是否成功，便於 UI 同步
    func deleteComment(from task: Task, comment: TaskComment) async -> Bool {
        guard userId != nil, task.id != nil else {
            ToastManager.shared.showToast(message: "用戶未登入或任務ID無效。", type: .error)
            return false
        }

        // RBAC Check for deleting comment
        let canDelete = await canDeleteComment(from: task, comment: comment)
        guard canDelete else {
            ToastManager.shared.showToast(message: "您沒有權限刪除此評論。", type: .error)
            return false
        }
        
        var updatedTask = task
        updatedTask.comments?.removeAll(where: { $0.id == comment.id })
        updatedTask.updatedAt = Date()

        do {
            try await taskService.updateTask(updatedTask) // Update the task in Firestore
            ToastManager.shared.showToast(message: "評論已刪除！", type: .success)
            return true
        } catch {
            print("❌ Error deleting comment: \(error)")
            ToastManager.shared.showToast(message: "刪除評論失敗：\(error.localizedDescription)", type: .error)
            return false
        }
    }

    func canDeleteComment(from task: Task, comment: TaskComment) async -> Bool {
        guard let currentUserId = userId else { return false }
        var hasPermission = false
        if let orgId = task.sourceOrgId {
            let canModerate = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.deleteAnyTaskCommentInOrg
            ])
            let canDeleteOwn = comment.authorUserId == currentUserId
            let hasOwnPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.deleteOwnTaskComment,
                AppPermissions.createTaskCommentInOrg
            ])
            hasPermission = canModerate || (canDeleteOwn && hasOwnPermission) || task.userId == currentUserId
        } else {
            // Personal task: 作者或評論作者可刪
            hasPermission = comment.authorUserId == currentUserId || task.userId == currentUserId
        }
        return hasPermission
    }
    
    func canAddComment(to task: Task) async -> Bool {
        guard userId != nil else { return false }
        
        if let orgId = task.sourceOrgId {
            guard let currentUserId = userId else { return false }
            let orgPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.createTaskCommentInOrg
            ])
            return orgPermission || isOwnerOrAssignee(task, currentUserId: currentUserId)
        } else {
            // Personal task: any authenticated user can comment on their own tasks
            guard let currentUserId = userId else { return false }
            return isOwnerOrAssignee(task, currentUserId: currentUserId)
        }
    }
    
    /// 判斷當前用戶是否可以刪除某個任務
    func canDelete(task: Task) async -> Bool {
        guard let currentUserId = userId else { return false }
        
        if let orgId = task.sourceOrgId {
            let orgPermission = await hasOrgPermission(orgId, permissions: [
                AppPermissions.manageAllOrgTasks,
                AppPermissions.deleteAnyTaskInOrg
            ])
            return orgPermission || task.userId == currentUserId
        } else {
            // Personal task: only author can delete
            return task.userId == currentUserId
        }
    }

    // MARK: - Filter & Sort

    /// 篩選任務（按類別和組織）
    func filteredTasks(_ tasks: [Task]) -> [Task] {
        var filtered = tasks

        // 篩選分類
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // 篩選組織
        if let orgId = selectedOrganizationId {
            filtered = filtered.filter { $0.sourceOrgId == orgId }
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
        case .custom:
            return tasks.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        }
    }

    // MARK: - Reordering
    
    // Define a simplified enum for list types to avoid dependency on View
    enum TaskListType {
        case today, week, backlog
    }
    
    func reorderTasks(in listType: TaskListType, from source: IndexSet, to destination: Int) {
        // 只有在自定義排序模式下才允許拖拽
        guard sortOption == .custom else {
            ToastManager.shared.showToast(message: "請先切換到「自定義」排序模式再進行拖拽。", type: .warning)
            return
        }
        
        var targetList: [Task]
        switch listType {
        case .today: targetList = todayTasks
        case .week: targetList = weekTasks
        case .backlog: targetList = backlogTasks
        }
        
        targetList.move(fromOffsets: source, toOffset: destination)
        
        updateListAndSave(targetList, type: listType)
    }
    
    func moveTask(fromId sourceId: String, toId destinationId: String, in listType: TaskListType) {
        guard sortOption == .custom else {
             ToastManager.shared.showToast(message: "請先切換到「自定義」排序模式再進行拖拽。", type: .warning)
             return
        }
        
        var targetList: [Task]
        switch listType {
        case .today: targetList = todayTasks
        case .week: targetList = weekTasks
        case .backlog: targetList = backlogTasks
        }
        
        guard let sourceIndex = targetList.firstIndex(where: { $0.id == sourceId }),
              let destIndex = targetList.firstIndex(where: { $0.id == destinationId }) else { return }
              
        let task = targetList.remove(at: sourceIndex)
        targetList.insert(task, at: destIndex)
        
        updateListAndSave(targetList, type: listType)
    }
    
    private func updateListAndSave(_ tasks: [Task], type: TaskListType) {
        // 更新本地列表
        switch type {
        case .today: todayTasks = tasks
        case .week: weekTasks = tasks
        case .backlog: backlogTasks = tasks
        }
        
        // 更新 sortOrder 並保存
        var tasksToUpdate: [Task] = []
        for (index, task) in tasks.enumerated() {
            if task.sortOrder != index {
                var updated = task
                updated.sortOrder = index
                // 更新本地引用
                switch type {
                case .today: todayTasks[index] = updated
                case .week: weekTasks[index] = updated
                case .backlog: backlogTasks[index] = updated
                }
                tasksToUpdate.append(updated)
            }
        }
        
        guard !tasksToUpdate.isEmpty else { return }
        
        _Concurrency.Task {
            do {
                try await taskService.batchUpdateTasks(tasksToUpdate)
            } catch {
                print("❌ Error updating sort order: \(error)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "保存排序失敗", type: .error)
                }
            }
        }
    }

    // MARK: - Week Statistics

    func weeklyStatistics() -> [(day: Date, duration: Int)] {
        let weekStart = Date.startOfWeek()
        let days = Date.daysOfWeek(startingFrom: weekStart)

        return days.map { day in
            let calendar = Calendar.current
            let duration = weekTasks
                .filter { task in
                    if let planned = task.plannedDate,
                       calendar.isDate(planned, equalTo: day, toGranularity: .day) {
                        return true
                    }
                    // 未排程但有 deadline，也計入當天，讓週視圖能反映壓力
                    if task.plannedDate == nil,
                       let deadline = task.deadlineAt,
                       calendar.isDate(deadline, equalTo: day, toGranularity: .day) {
                        return true
                    }
                    return false
                }
                .reduce(0) { partial, task in
                    partial + (task.estimatedMinutes ?? 0)
                }
            return (day, duration)
        }
    }

    func fetchTask(id: String) async throws -> Task? {
        try await taskService.fetchTask(id: id)
    }

    func isTaskBlocked(_ task: Task) -> Bool {
        let allTasks = todayTasks + weekTasks + backlogTasks
        return !dependencyService.canStartTask(task, allTasks: allTasks)
    }
}
