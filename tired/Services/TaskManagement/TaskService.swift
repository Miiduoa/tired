import Foundation
import FirebaseFirestore
import Combine

// MARK: - Task Service
@MainActor
class TaskService: BaseFirestoreService, ObservableObject {

    static let shared = TaskService()

    private let COLLECTION = "tasks"
    private let MAX_TODAY_FOCUS = 5
    private let SOFT_RECOMMENDED_FOCUS = 3

    @Published var tasks: [Task] = []
    private var listener: ListenerRegistration?

    // MARK: - Basic CRUD

    func createTask(_ task: Task) async throws {
        var newTask = task
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        newTask.localUpdatedAt = Date()

        // Update denormalized deadline_date
        if let deadline = newTask.deadlineAt {
            newTask.deadlineDate = DateUtils.formatDateKey(deadline)
        }

        try await create(newTask, collection: COLLECTION)
    }

    func updateTask(_ task: Task) async throws {
        var updatedTask = task
        updatedTask.updatedAt = Date()
        updatedTask.localUpdatedAt = Date()

        // Update denormalized deadline_date
        if let deadline = updatedTask.deadlineAt {
            updatedTask.deadlineDate = DateUtils.formatDateKey(deadline)
        } else {
            updatedTask.deadlineDate = nil
        }

        try await update(updatedTask, collection: COLLECTION)
    }

    func getTask(id: String) async throws -> Task? {
        return try await read(id: id, collection: COLLECTION, as: Task.self)
    }

    func deleteTask(id: String) async throws {
        try await softDelete(id: id, collection: COLLECTION)
    }

    // MARK: - Query Tasks

    func getTasks(userId: String, filters: [QueryFilter] = []) async throws -> [Task] {
        var allFilters = [QueryFilter.equals(field: "userId", value: userId)]
        allFilters.append(contentsOf: filters)

        return try await query(
            collection: COLLECTION,
            filters: allFilters,
            as: Task.self
        )
    }

    func getOpenTasks(userId: String, termConfig: TermConfig?) async throws -> [Task] {
        // Get S_term_TW_open tasks
        var filters: [QueryFilter] = [
            .equals(field: "userId", value: userId),
            .equals(field: "state", value: "open"),
            .isNull(field: "deletedAt")
        ]

        let allTasks = try await query(
            collection: COLLECTION,
            filters: filters,
            as: Task.self
        )

        // Filter based on term (client-side for complex logic)
        guard let currentTermId = termConfig?.termId else {
            // No term configured, return all non-school tasks
            return allTasks.filter { $0.category != .school }
        }

        return allTasks.filter { task in
            if task.category != .school {
                return true
            }
            // School tasks: must match current term or be cross-term important
            return task.termId == currentTermId || task.isCrossTermImportant
        }
    }

    func getTodayTasks(userId: String, todayDate: Date, termConfig: TermConfig?) async throws -> [Task] {
        let openTasks = try await getOpenTasks(userId: userId, termConfig: termConfig)

        return openTasks.filter { task in
            let overdue = task.deadlineAt != nil && DateUtils.isBefore(task.deadlineAt!, todayDate)
            let deadlineToday = task.deadlineAt != nil && DateUtils.isSameDay(task.deadlineAt!, todayDate)
            let hasPlanned = task.plannedWorkDate != nil && !DateUtils.isAfter(task.plannedWorkDate!, todayDate)

            return overdue || deadlineToday || hasPlanned
        }
    }

    func getBacklogTasks(userId: String, termConfig: TermConfig?) async throws -> [Task] {
        let openTasks = try await getOpenTasks(userId: userId, termConfig: termConfig)

        return openTasks.filter { task in
            task.plannedWorkDate == nil
        }
    }

    // MARK: - Listen to Tasks (Real-time)

    func listenToTasks(userId: String, onChange: @escaping ([Task]) -> Void) {
        listener?.remove()

        listener = listen(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .isNull(field: "deletedAt")
            ],
            orderBy: [("createdAt", false)],
            onChange: onChange
        )
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Task State Operations

    func completeTask(_ task: Task, silent: Bool = false, recordUndo: Bool = true) async throws {
        var updatedTask = task
        updatedTask.state = .done
        updatedTask.doneAt = Date()
        updatedTask.isTodayFocus = false
        updatedTask.committedWeekStartDate = nil
        updatedTask.isDateLocked = false

        // Mark inbox handled
        if updatedTask.isInbox {
            updatedTask.isInbox = false
        }

        try await updateTask(updatedTask)

        if !silent {
            // TODO: Show toast with undo
            print("✓ 已完成「\(task.title)」")
        }
    }

    func skipTask(_ task: Task, silent: Bool = false, recordUndo: Bool = true) async throws {
        var updatedTask = task
        updatedTask.state = .skipped
        updatedTask.skippedAt = Date()
        updatedTask.isTodayFocus = false
        updatedTask.committedWeekStartDate = nil
        updatedTask.isDateLocked = false

        // Mark inbox handled
        if updatedTask.isInbox {
            updatedTask.isInbox = false
        }

        try await updateTask(updatedTask)

        if !silent {
            // TODO: Show toast with undo
            print("✓ 已標記「\(task.title)」為不做")
        }
    }

    func reopenTask(_ task: Task) async throws {
        var updatedTask = task
        updatedTask.state = .open
        updatedTask.doneAt = nil
        updatedTask.skippedAt = nil

        try await updateTask(updatedTask)
    }

    // MARK: - Focus Management

    func setTodayFocus(_ task: Task, isFocus: Bool, todayDate: Date, allTasks: [Task]) async throws -> Bool {
        if isFocus {
            let currentFocus = allTasks.filter {
                $0.state == .open &&
                $0.deletedAt == nil &&
                $0.isTodayFocus &&
                $0.plannedWorkDate != nil &&
                DateUtils.isSameDay($0.plannedWorkDate!, todayDate)
            }

            if currentFocus.count >= MAX_TODAY_FOCUS {
                // TODO: Show dialog asking confirmation
                print("⚠️ 焦點太多了，建議一次只抓 \(SOFT_RECOMMENDED_FOCUS) 顆，最多 \(MAX_TODAY_FOCUS) 顆")
                // For now, we'll allow it but return false to indicate warning
                // In full implementation, we'd show a dialog
            }
        }

        var updatedTask = task
        updatedTask.isTodayFocus = isFocus

        if isFocus {
            // Auto-schedule to today if not scheduled or scheduled in the past
            if updatedTask.plannedWorkDate == nil || DateUtils.isBefore(updatedTask.plannedWorkDate!, todayDate) {
                updatedTask.plannedWorkDate = todayDate
                updatedTask.firstPlannedDate = updatedTask.firstPlannedDate ?? todayDate
            }

            // Mark inbox handled
            if updatedTask.isInbox {
                updatedTask.isInbox = false
            }
        }

        try await updateTask(updatedTask)
        return true
    }

    // MARK: - Scheduling Operations

    func setPlannedDateManual(_ task: Task, date: Date?) async throws {
        var updatedTask = task
        updatedTask.plannedWorkDate = date
        updatedTask.firstPlannedDate = updatedTask.firstPlannedDate ?? date
        updatedTask.isDateLocked = date != nil // Lock when manually scheduled

        if updatedTask.isInbox {
            updatedTask.isInbox = false
        }

        try await updateTask(updatedTask)
    }

    func clearPlannedDate(_ task: Task) async throws {
        var updatedTask = task
        updatedTask.plannedWorkDate = nil
        updatedTask.isDateLocked = false

        try await updateTask(updatedTask)
    }

    func postponeToDate(_ task: Task, newDate: Date) async throws {
        var updatedTask = task
        updatedTask.plannedWorkDate = newDate
        updatedTask.firstPlannedDate = updatedTask.firstPlannedDate ?? newDate

        try await updateTask(updatedTask)
    }

    func postponeToNextWeek(_ task: Task, weekStartDate: Date) async throws {
        var updatedTask = task
        updatedTask.postponeToNextWeekCount += 1

        // Clear committed week if it was committed to current week
        if let committed = updatedTask.committedWeekStartDate,
           DateUtils.isSameDay(committed, weekStartDate) {
            updatedTask.committedWeekStartDate = nil
        }

        // Clear planned date
        updatedTask.plannedWorkDate = nil
        updatedTask.isDateLocked = false

        try await updateTask(updatedTask)
    }

    // MARK: - Deadline Management

    func setDeadline(_ task: Task, deadline: Date?) async throws {
        var updatedTask = task
        updatedTask.deadlineAt = deadline
        updatedTask.deadlineDate = deadline != nil ? DateUtils.formatDateKey(deadline!) : nil

        try await updateTask(updatedTask)
    }

    // MARK: - Dependency Management

    func addDependency(blockedTask: Task, blockingTaskId: String, allTasks: [Task]) async throws {
        // Check for cycles
        if blockedTask.id == blockingTaskId {
            throw TaskError.circularDependency
        }

        if wouldCreateCycle(blockedTaskId: blockedTask.id, blockingTaskId: blockingTaskId, allTasks: allTasks) {
            throw TaskError.circularDependency
        }

        // Update blocked task
        var updatedBlockedTask = blockedTask
        if !updatedBlockedTask.blockedByTaskIds.contains(blockingTaskId) {
            updatedBlockedTask.blockedByTaskIds.append(blockingTaskId)
        }
        try await updateTask(updatedBlockedTask)

        // Update blocking task
        if let blockingTask = allTasks.first(where: { $0.id == blockingTaskId }) {
            var updatedBlockingTask = blockingTask
            if !updatedBlockingTask.blockingTaskIds.contains(blockedTask.id) {
                updatedBlockingTask.blockingTaskIds.append(blockedTask.id)
            }
            try await updateTask(updatedBlockingTask)
        }
    }

    func removeDependency(blockedTask: Task, blockingTaskId: String, allTasks: [Task]) async throws {
        var updatedBlockedTask = blockedTask
        updatedBlockedTask.blockedByTaskIds.removeAll { $0 == blockingTaskId }
        try await updateTask(updatedBlockedTask)

        if let blockingTask = allTasks.first(where: { $0.id == blockingTaskId }) {
            var updatedBlockingTask = blockingTask
            updatedBlockingTask.blockingTaskIds.removeAll { $0 == blockedTask.id }
            try await updateTask(updatedBlockingTask)
        }
    }

    private func wouldCreateCycle(blockedTaskId: String, blockingTaskId: String, allTasks: [Task]) -> Bool {
        // Simple cycle detection using DFS
        var visited = Set<String>()
        var stack = [blockingTaskId]

        while !stack.isEmpty {
            let current = stack.removeLast()
            if current == blockedTaskId {
                return true
            }

            if visited.contains(current) {
                continue
            }
            visited.insert(current)

            if let task = allTasks.first(where: { $0.id == current }) {
                stack.append(contentsOf: task.blockedByTaskIds)
            }
        }

        return false
    }

    // MARK: - Work Session Management

    func addWorkSession(_ task: Task, session: WorkSession) async throws {
        var updatedTask = task
        updatedTask.workSessions.append(session)
        updatedTask.actualWorkMin = (updatedTask.actualWorkMin ?? 0) + session.durationMin

        try await updateTask(updatedTask)
    }

    // MARK: - Evidence Management

    func addEvidence(_ task: Task, evidence: TaskEvidence) async throws {
        var updatedTask = task
        updatedTask.evidences.append(evidence)

        try await updateTask(updatedTask)
    }

    func removeEvidence(_ task: Task, evidenceId: String) async throws {
        var updatedTask = task
        updatedTask.evidences.removeAll { $0.id == evidenceId }

        try await updateTask(updatedTask)
    }

    // MARK: - Batch Operations

    func batchUpdateTasks(_ tasks: [Task]) async throws {
        for task in tasks {
            try await updateTask(task)
        }
    }

    func batchCompleteTasks(_ tasks: [Task]) async throws {
        for task in tasks {
            try await completeTask(task, silent: true, recordUndo: false)
        }
    }

    func batchSkipTasks(_ tasks: [Task]) async throws {
        for task in tasks {
            try await skipTask(task, silent: true, recordUndo: false)
        }
    }

    func batchPostponeTasks(_ tasks: [Task], newDate: Date) async throws {
        for task in tasks {
            try await postponeToDate(task, newDate: newDate)
        }
    }
}

// MARK: - Task Error
enum TaskError: Error, LocalizedError {
    case circularDependency
    case notFound
    case invalidOperation

    var errorDescription: String? {
        switch self {
        case .circularDependency:
            return "無法添加依賴：會形成循環依賴"
        case .notFound:
            return "找不到任務"
        case .invalidOperation:
            return "無效的操作"
        }
    }
}
