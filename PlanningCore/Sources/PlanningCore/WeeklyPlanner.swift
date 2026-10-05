public enum PlanningPriority: Int, Sendable {
    case low = 1
    case medium = 2
    case high = 3
}

public struct PlanningTask: Equatable, Sendable {
    public let id: String
    public let durationMinutes: Int
    public let priority: PlanningPriority
    public let deadlineDay: Int?
    public let lockedDay: Int?
    public let isDone: Bool

    public init(
        id: String,
        durationMinutes: Int,
        priority: PlanningPriority,
        deadlineDay: Int? = nil,
        lockedDay: Int? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.priority = priority
        self.deadlineDay = deadlineDay
        self.lockedDay = lockedDay
        self.isDone = isDone
    }
}

public struct BusyBlock: Equatable, Sendable {
    public let day: Int
    public let durationMinutes: Int

    public init(day: Int, durationMinutes: Int) {
        self.day = day
        self.durationMinutes = durationMinutes
    }
}

public enum SkipReason: String, Equatable, Sendable {
    case invalidDuration
    case deadlineOutsideWindow
    case noCapacity
}

public struct PlanningResult: Equatable, Sendable {
    public let assignments: [String: Int]
    public let dayLoad: [Int]
    public let skipped: [String: SkipReason]

    public init(
        assignments: [String: Int],
        dayLoad: [Int],
        skipped: [String: SkipReason]
    ) {
        self.assignments = assignments
        self.dayLoad = dayLoad
        self.skipped = skipped
    }
}

public struct WeeklyPlanner: Sendable {
    public let days: Int
    public let dailyCapacityMinutes: Int

    public init(
        days: Int = 7,
        dailyCapacityMinutes: Int
    ) {
        precondition(days > 0)
        precondition(dailyCapacityMinutes > 0)

        self.days = days
        self.dailyCapacityMinutes = dailyCapacityMinutes
    }

    public func plan(
        tasks: [PlanningTask],
        busyBlocks: [BusyBlock] = []
    ) -> PlanningResult {
        var assignments: [String: Int] = [:]
        var skipped: [String: SkipReason] = [:]
        var dayLoad = Array(repeating: 0, count: days)

        for block in busyBlocks {
            guard isValidDay(block.day), block.durationMinutes > 0 else {
                continue
            }
            dayLoad[block.day] += block.durationMinutes
        }

        for task in tasks {
            guard !task.isDone else { continue }
            guard task.durationMinutes > 0 else {
                skipped[task.id] = .invalidDuration
                continue
            }

            if let lockedDay = task.lockedDay {
                guard isValidDay(lockedDay) else {
                    skipped[task.id] = .deadlineOutsideWindow
                    continue
                }

                assignments[task.id] = lockedDay
                dayLoad[lockedDay] += task.durationMinutes
            }
        }

        let candidates = tasks
            .filter {
                !$0.isDone
                && $0.lockedDay == nil
                && $0.durationMinutes > 0
            }
            .sorted(by: comesBefore)

        for task in candidates {
            let lastDay: Int

            if let deadline = task.deadlineDay {
                guard deadline >= 0 else {
                    skipped[task.id] = .deadlineOutsideWindow
                    continue
                }
                lastDay = min(deadline, days - 1)
            } else {
                lastDay = days - 1
            }

            let eligibleDays = 0...lastDay
            let feasibleDays = eligibleDays.filter { day in
                dayLoad[day] + task.durationMinutes
                    <= dailyCapacityMinutes
            }

            guard let selectedDay = feasibleDays.min(
                by: { score(task, day: $0, load: dayLoad[$0])
                    < score(task, day: $1, load: dayLoad[$1]) }
            ) else {
                skipped[task.id] = .noCapacity
                continue
            }

            assignments[task.id] = selectedDay
            dayLoad[selectedDay] += task.durationMinutes
        }

        return PlanningResult(
            assignments: assignments,
            dayLoad: dayLoad,
            skipped: skipped
        )
    }

    private func isValidDay(_ day: Int) -> Bool {
        (0..<days).contains(day)
    }

    private func comesBefore(
        _ lhs: PlanningTask,
        _ rhs: PlanningTask
    ) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority.rawValue > rhs.priority.rawValue
        }

        let lhsDeadline = lhs.deadlineDay ?? Int.max
        let rhsDeadline = rhs.deadlineDay ?? Int.max

        if lhsDeadline != rhsDeadline {
            return lhsDeadline < rhsDeadline
        }

        return lhs.id < rhs.id
    }

    private func score(
        _ task: PlanningTask,
        day: Int,
        load: Int
    ) -> Int {
        let latenessWeight = task.priority.rawValue * 30
        return load + day * latenessWeight
    }
}
