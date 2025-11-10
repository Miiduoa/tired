import Foundation

// MARK: - Autoplan Result
struct AutoplanResult {
    var scheduledTasks: [Task]
    var failedTasks: [(task: Task, reason: FailureReason)]

    enum FailureReason {
        case deadlineTooClose
        case capacityOverload
        case dependencyNotScheduled
        case noSuitableSlot

        var description: String {
            switch self {
            case .deadlineTooClose:
                return "截止日期太近"
            case .capacityOverload:
                return "容量已滿"
            case .dependencyNotScheduled:
                return "依賴任務未排程"
            case .noSuitableSlot:
                return "找不到合適時段"
            }
        }
    }
}

// MARK: - Autoplan Service
@MainActor
class AutoplanService {

    static let shared = AutoplanService()

    private let MAX_DAY_OVERLOAD_RATIO = 1.8

    private init() {}

    // MARK: - Weekly Autoplan

    func weeklyAutoplan(
        weekStart: Date,
        userId: String,
        profile: UserProfile,
        termConfig: TermConfig?,
        allTasks: [Task],
        events: [Event]
    ) async throws -> AutoplanResult {

        let weekEnd = DateUtils.addDays(weekStart, 6)

        // 1. Get candidates
        var candidates = getWeeklyCandidates(
            weekStart: weekStart,
            weekEnd: weekEnd,
            allTasks: allTasks
        )

        // 2. Topological sort by dependencies
        candidates = topologicalSort(tasks: candidates, allTasks: allTasks)

        // 3. Schedule tasks
        var scheduledTasks: [Task] = []
        var failedTasks: [(task: Task, reason: AutoplanResult.FailureReason)] = []

        for var task in candidates {
            if let scheduled = try await scheduleTask(
                task: &task,
                weekStart: weekStart,
                weekEnd: weekEnd,
                profile: profile,
                scheduledTasks: scheduledTasks,
                allTasks: allTasks,
                events: events
            ) {
                scheduledTasks.append(scheduled)
            } else {
                let reason = determineFailureReason(
                    task: task,
                    weekStart: weekStart,
                    weekEnd: weekEnd,
                    profile: profile,
                    scheduledTasks: scheduledTasks,
                    allTasks: allTasks,
                    events: events
                )
                failedTasks.append((task, reason))
            }
        }

        return AutoplanResult(
            scheduledTasks: scheduledTasks,
            failedTasks: failedTasks
        )
    }

    // MARK: - Single Task Scheduling

    func scheduleSingleTask(
        task: Task,
        weekStart: Date,
        userId: String,
        profile: UserProfile,
        allTasks: [Task],
        events: [Event]
    ) async throws -> Task? {

        let weekEnd = DateUtils.addDays(weekStart, 6)
        var mutableTask = task

        return try await scheduleTask(
            task: &mutableTask,
            weekStart: weekStart,
            weekEnd: weekEnd,
            profile: profile,
            scheduledTasks: [],
            allTasks: allTasks,
            events: events
        )
    }

    // MARK: - Get Candidates

    private func getWeeklyCandidates(
        weekStart: Date,
        weekEnd: Date,
        allTasks: [Task]
    ) -> [Task] {

        return allTasks.filter { task in
            // Must be open
            guard task.state == .open && task.deletedAt == nil else {
                return false
            }

            // Respect date lock
            if task.isDateLocked,
               let planned = task.plannedWorkDate,
               !DateUtils.isBefore(planned, weekStart),
               !DateUtils.isAfter(planned, weekEnd) {
                return false
            }

            // Include if:
            // 1. Has deadline this week but not scheduled
            if let deadline = task.deadlineAt,
               !DateUtils.isBefore(deadline, weekStart),
               !DateUtils.isAfter(deadline, weekEnd),
               task.plannedWorkDate == nil {
                return true
            }

            // 2. Has committed week but not scheduled
            if let committed = task.committedWeekStartDate,
               DateUtils.isSameDay(committed, weekStart),
               task.plannedWorkDate == nil {
                return true
            }

            // 3. Has past planned date but high priority
            if let planned = task.plannedWorkDate,
               DateUtils.isBefore(planned, weekStart),
               (task.priority == .P0 || task.priority == .P1) {
                return true
            }

            // 4. Old backlog with high priority
            if task.plannedWorkDate == nil,
               (task.priority == .P0 || task.priority == .P1),
               let created = task.firstPlannedDate ?? task.createdAt as Date?,
               DateUtils.diffInCalendarDays(from: created, to: Date()) > 7 {
                return true
            }

            return false
        }
    }

    // MARK: - Topological Sort

    private func topologicalSort(tasks: [Task], allTasks: [Task]) -> [Task] {
        var sorted: [Task] = []
        var visited = Set<String>()
        var visiting = Set<String>()

        func visit(_ task: Task) {
            if visited.contains(task.id) { return }
            if visiting.contains(task.id) { return } // Cycle detected, skip

            visiting.insert(task.id)

            // Visit dependencies first
            for depId in task.blockedByTaskIds {
                if let depTask = tasks.first(where: { $0.id == depId }) {
                    visit(depTask)
                }
            }

            visiting.remove(task.id)
            visited.insert(task.id)
            sorted.append(task)
        }

        for task in tasks {
            visit(task)
        }

        return sorted
    }

    // MARK: - Schedule Task

    private func scheduleTask(
        task: inout Task,
        weekStart: Date,
        weekEnd: Date,
        profile: UserProfile,
        scheduledTasks: [Task],
        allTasks: [Task],
        events: [Event]
    ) async throws -> Task? {

        // Check dependencies are scheduled
        let allScheduledIds = Set(scheduledTasks.map { $0.id })
        for depId in task.blockedByTaskIds {
            if !allScheduledIds.contains(depId) {
                // Check if dependency is in allTasks and open
                if let dep = allTasks.first(where: { $0.id == depId }),
                   dep.state == .open,
                   dep.deletedAt == nil {
                    return nil // Dependency not scheduled yet
                }
            }
        }

        // Find best slot
        let effort = task.effortForScheduling()
        var bestDate: Date?
        var bestRatio: Double = Double.infinity

        for dayOffset in 0...6 {
            let date = DateUtils.addDays(weekStart, dayOffset)

            // Check deadline constraint
            if let deadline = task.deadlineAt {
                let deadlineDay = DateUtils.startOfDay(deadline)
                if DateUtils.isAfter(date, deadlineDay) || DateUtils.isSameDay(date, deadlineDay) {
                    continue
                }
            }

            // Check dependency constraint
            var latestDepDate: Date?
            for depId in task.blockedByTaskIds {
                if let dep = scheduledTasks.first(where: { $0.id == depId }),
                   let depPlanned = dep.plannedWorkDate {
                    if latestDepDate == nil || DateUtils.isAfter(depPlanned, latestDepDate!) {
                        latestDepDate = depPlanned
                    }
                }
            }

            if let latestDep = latestDepDate, !DateUtils.isAfter(date, latestDep) {
                continue
            }

            // Calculate current load
            let currentTasks = scheduledTasks + allTasks.filter { t in
                guard let planned = t.plannedWorkDate else { return false }
                return DateUtils.isSameDay(planned, date) && t.state == .open
            }

            let currentLoad = currentTasks.reduce(0) { sum, t in
                sum + t.effortForScheduling()
            }

            let capacity = CapacityCalculator.studyCapacityMin(
                on: date,
                profile: profile,
                events: events
            )

            if capacity <= 0 { continue }

            let newLoad = currentLoad + effort
            let newRatio = Double(newLoad) / Double(capacity)

            // Skip if overload
            if newRatio > MAX_DAY_OVERLOAD_RATIO { continue }

            // Find best (lowest ratio) date
            if newRatio < bestRatio {
                bestRatio = newRatio
                bestDate = date
            }
        }

        guard let scheduledDate = bestDate else {
            return nil
        }

        // Update task
        task.plannedWorkDate = scheduledDate
        task.firstPlannedDate = task.firstPlannedDate ?? scheduledDate
        task.lastAutoplanWeekStart = weekStart
        task.isDateLocked = false // Autoplan doesn't lock dates

        if task.isInbox {
            task.isInbox = false
        }

        return task
    }

    // MARK: - Determine Failure Reason

    private func determineFailureReason(
        task: Task,
        weekStart: Date,
        weekEnd: Date,
        profile: UserProfile,
        scheduledTasks: [Task],
        allTasks: [Task],
        events: [Event]
    ) -> AutoplanResult.FailureReason {

        // Check dependencies
        let allScheduledIds = Set(scheduledTasks.map { $0.id })
        for depId in task.blockedByTaskIds {
            if !allScheduledIds.contains(depId) {
                if let dep = allTasks.first(where: { $0.id == depId }),
                   dep.state == .open,
                   dep.deletedAt == nil {
                    return .dependencyNotScheduled
                }
            }
        }

        // Check deadline
        if let deadline = task.deadlineAt {
            let daysUntilDeadline = DateUtils.diffInCalendarDays(
                from: Date(),
                to: deadline
            )
            if daysUntilDeadline <= 1 {
                return .deadlineTooClose
            }
        }

        // Check capacity
        var hasAnyCapacity = false
        for dayOffset in 0...6 {
            let date = DateUtils.addDays(weekStart, dayOffset)
            let capacity = CapacityCalculator.studyCapacityMin(
                on: date,
                profile: profile,
                events: events
            )
            if capacity > 0 {
                hasAnyCapacity = true
                break
            }
        }

        if !hasAnyCapacity {
            return .capacityOverload
        }

        return .noSuitableSlot
    }
}
