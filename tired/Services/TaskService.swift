import Foundation
import FirebaseFirestore
import Combine

/// 任務管理核心服務
class TaskService: ObservableObject {
    static let shared = TaskService()

    @Published var tasks: [Task] = []
    @Published var userProfile: UserProfile?

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var userId: String?

    private init() {}

    // MARK: - 初始化

    func initialize(userId: String) {
        self.userId = userId
        loadUserProfile(userId: userId)
        loadTasks(userId: userId)
    }

    // MARK: - User Profile

    func loadUserProfile(userId: String) {
        db.collection("user_profiles").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data() else {
                // 創建新 profile
                let profile = UserProfile(userId: userId)
                self?.userProfile = profile
                self?.saveUserProfile(profile)
                return
            }

            if let profile = try? Firestore.Decoder().decode(UserProfile.self, from: data) {
                self?.userProfile = profile
                AppSession.shared.updateSession(with: profile)
            }
        }
    }

    func saveUserProfile(_ profile: UserProfile) {
        guard let data = try? Firestore.Encoder().encode(profile) else { return }
        db.collection("user_profiles").document(profile.userId).setData(data)
    }

    func updateUserProfile(_ update: (inout UserProfile) -> Void) {
        guard var profile = userProfile else { return }
        update(&profile)
        profile.updatedAt = Date()
        userProfile = profile
        saveUserProfile(profile)
    }

    // MARK: - Tasks CRUD

    func loadTasks(userId: String) {
        db.collection("tasks")
            .whereField("user_id", isEqualTo: userId)
            .whereField("deleted_at", isEqualTo: NSNull())
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                self?.tasks = documents.compactMap { doc in
                    try? doc.data(as: Task.self)
                }
            }
    }

    func createTask(_ task: Task) {
        var newTask = task
        newTask.updatedAt = Date()

        guard let data = try? Firestore.Encoder().encode(newTask) else { return }
        db.collection("tasks").document(newTask.id).setData(data)
    }

    func updateTask(_ task: Task) {
        var updatedTask = task
        updatedTask.updatedAt = Date()

        guard let data = try? Firestore.Encoder().encode(updatedTask) else { return }
        db.collection("tasks").document(updatedTask.id).setData(data, merge: true)
    }

    func deleteTask(_ task: Task) {
        var deletedTask = task
        deletedTask.deletedAt = Date()
        deletedTask.updatedAt = Date()
        updateTask(deletedTask)
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task, silent: Bool = false, recordUndo: Bool = true) {
        if recordUndo && !silent {
            UndoService.shared.recordAction(type: "complete", tasks: [task])
        }

        var updatedTask = task
        updatedTask.state = .done
        updatedTask.doneAt = Date()
        updatedTask.isTodayFocus = false
        updatedTask.committedWeekStartDate = nil
        updatedTask.isDateLocked = false
        markInboxHandled(&updatedTask)

        updateTask(updatedTask)
    }

    func skipTask(_ task: Task, silent: Bool = false, recordUndo: Bool = true) {
        if recordUndo && !silent {
            UndoService.shared.recordAction(type: "skip", tasks: [task])
        }

        var updatedTask = task
        updatedTask.state = .skipped
        updatedTask.skippedAt = Date()
        updatedTask.isTodayFocus = false
        updatedTask.committedWeekStartDate = nil
        updatedTask.isDateLocked = false
        markInboxHandled(&updatedTask)

        updateTask(updatedTask)
    }

    func setTodayFocus(_ task: Task, isFocus: Bool) {
        var updatedTask = task
        updatedTask.isTodayFocus = isFocus

        if isFocus {
            let today = AppSession.shared.todayDate
            if updatedTask.plannedWorkDate == nil || updatedTask.plannedWorkDate!.isBefore(today) {
                updatedTask.plannedWorkDate = today
                updatedTask.firstPlannedDate = updatedTask.firstPlannedDate ?? today
            }
            markInboxHandled(&updatedTask)
        }

        updateTask(updatedTask)
    }

    func setPlannedDate(_ task: Task, date: Date?, isManual: Bool = false) {
        var updatedTask = task
        updatedTask.plannedWorkDate = date
        updatedTask.firstPlannedDate = updatedTask.firstPlannedDate ?? date

        if isManual && date != nil {
            updatedTask.isDateLocked = true
        } else if date == nil {
            updatedTask.isDateLocked = false
        }

        if date != nil {
            markInboxHandled(&updatedTask)
        }

        updateTask(updatedTask)
    }

    private func markInboxHandled(_ task: inout Task) {
        if task.isInbox {
            task.isInbox = false
        }
    }

    // MARK: - Today / This Week / Backlog

    func getTodayTasks() -> [Task] {
        let today = AppSession.shared.todayDate
        let tz = AppSession.shared.timeZone

        return getOpenTermTasks().filter { task in
            let overdue = isDeadlineOverdue(task, today: today, timeZone: tz)
            let deadlineToday = task.deadlineAt != nil && task.deadlineAt!.isSameDay(as: today, timeZone: tz)
            let hasPlanned = task.plannedWorkDate != nil && !task.plannedWorkDate!.isAfter(today, timeZone: tz)

            return overdue || deadlineToday || hasPlanned
        }
        .sorted(by: sortTasksForTodayOrWeek)
    }

    func getThisWeekTasks() -> [Date: [Task]] {
        let weekStart = AppSession.shared.weekStart()
        var result: [Date: [Task]] = [:]

        for i in 0..<7 {
            let day = DateUtils.addDays(weekStart, i)
            let dayTasks = getOpenTermTasks().filter { task in
                task.plannedWorkDate?.isSameDay(as: day) == true
            }
            .sorted(by: sortTasksForTodayOrWeek)

            result[day] = dayTasks
        }

        return result
    }

    func getBacklogTasks() -> [Task] {
        return getOpenTermTasks().filter { task in
            task.plannedWorkDate == nil
        }
        .sorted { a, b in
            if a.isInbox != b.isInbox { return a.isInbox }
            if a.priority != b.priority {
                return priorityOrder(a.priority) < priorityOrder(b.priority)
            }
            return a.createdAt < b.createdAt
        }
    }

    // MARK: - Helpers

    private func getOpenTermTasks() -> [Task] {
        guard let currentTermId = userProfile?.currentTermId else {
            return tasks.filter { $0.state == .open && $0.deletedAt == nil }
        }

        return tasks.filter { task in
            task.state == .open && task.deletedAt == nil &&
            (task.category != .school ||
             task.termId == currentTermId ||
             task.isCrossTermImportant)
        }
    }

    private func isDeadlineOverdue(_ task: Task, today: Date, timeZone: TimeZone) -> Bool {
        guard let deadline = task.deadlineAt else { return false }
        return deadline.isBefore(today, timeZone: timeZone)
    }

    private func sortTasksForTodayOrWeek(_ a: Task, _ b: Task) -> Bool {
        // 焦點先
        if a.isTodayFocus != b.isTodayFocus {
            return a.isTodayFocus
        }

        // 優先度
        if a.priority != b.priority {
            return priorityOrder(a.priority) < priorityOrder(b.priority)
        }

        // deadline
        if let aDeadline = a.deadlineAt, let bDeadline = b.deadlineAt {
            return aDeadline < bDeadline
        }

        // created_at
        return a.createdAt < b.createdAt
    }

    private func priorityOrder(_ priority: Task.Priority) -> Int {
        switch priority {
        case .P0: return 0
        case .P1: return 1
        case .P2: return 2
        case .P3: return 3
        }
    }

    // MARK: - Capacity & Load

    func loadRatioForDay(_ date: Date) -> Double {
        let load = loadMinForDay(date)
        let capacity = studyCapacityForDay(date)

        if capacity <= 0 { return .infinity }
        return Double(load) / Double(capacity)
    }

    private func loadMinForDay(_ date: Date) -> Int {
        return tasks.filter { task in
            task.state == .open &&
            task.plannedWorkDate?.isSameDay(as: date) == true
        }
        .reduce(0) { $0 + effortForScheduling($1) }
    }

    private func studyCapacityForDay(_ date: Date) -> Int {
        guard let profile = userProfile else { return 0 }

        let baseCapacity = DateUtils.isWeekend(date) ?
            profile.weekendCapacityMin : profile.weekdayCapacityMin

        if baseCapacity == 0 { return 0 }

        // TODO: 減去 busy_min (events)
        return max(baseCapacity, 0)
    }

    private func effortForScheduling(_ task: Task) -> Int {
        if let actual = task.actualWorkMin, actual > 0 {
            return min(max(actual, 15), 240)
        }
        return task.estimatedEffortMin
    }

    // MARK: - Streak & Achievements

    func updateStreak() {
        guard var profile = userProfile else { return }

        let today = AppSession.shared.todayDate
        let yesterday = AppSession.shared.oldLastOpenDate ?? DateUtils.addDays(today, -1)

        let todayCompleted = getEffectiveCompletedTasksOn(date: today)
        if todayCompleted.isEmpty { return }

        let yesterdayCompleted = getEffectiveCompletedTasksOn(date: yesterday)

        if !yesterdayCompleted.isEmpty || profile.streakDays == 0 {
            profile.streakDays += 1
        } else {
            profile.streakDays = 1
        }

        profile.lastStreakDate = today
        userProfile = profile
        saveUserProfile(profile)
    }

    private func getEffectiveCompletedTasksOn(date: Date) -> [Task] {
        guard let currentTermId = userProfile?.currentTermId else { return [] }

        return tasks.filter { task in
            task.state == .done &&
            task.deletedAt == nil &&
            task.doneAt?.isSameDay(as: date) == true &&
            (task.category != .school ||
             task.termId == currentTermId ||
             task.isCrossTermImportant)
        }
    }
}
