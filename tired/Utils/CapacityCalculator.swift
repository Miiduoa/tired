import Foundation

// MARK: - Capacity Calculator
/// 計算每日容量、負載和壓力比例
class CapacityCalculator {

    // MARK: - Constants
    static let MAX_DAY_OVERLOAD_RATIO: Double = 1.8

    // MARK: - User Capacity

    /// Get user's study capacity for a specific date
    static func capacityMin(for date: Date, profile: UserProfile, timeZone: TimeZone = .current) -> Int {
        return profile.capacityMinutes(for: date)
    }

    // MARK: - Busy Time from Events

    /// Calculate total busy minutes from events on a specific date
    static func busyMin(on date: Date, events: [Event], timeZone: TimeZone = .current) -> Int {
        let dayKey = DateUtils.formatDateKey(date, timeZone: timeZone)

        // Filter events that overlap with this date
        let relevantEvents = events.filter { event in
            event.startDate <= dayKey && event.endDate >= dayKey && event.blocksStudyTime
        }

        var totalBusyMin = 0

        for event in relevantEvents {
            let start = DateUtils.clampToDay(
                event.effectiveStartTime(timeZone: timeZone),
                day: date,
                isAllDay: event.isAllDay,
                timeZone: timeZone
            )

            let end = DateUtils.clampToDay(
                event.effectiveEndTime(timeZone: timeZone),
                day: date,
                isAllDay: event.isAllDay,
                timeZone: timeZone
            )

            let duration = DateUtils.diffInMinutes(from: start, to: end)
            totalBusyMin += max(duration, 0)
        }

        return totalBusyMin
    }

    // MARK: - Task Load

    /// Calculate total task load minutes on a specific date
    static func loadMin(on date: Date, tasks: [Task], timeZone: TimeZone = .current) -> Int {
        // Filter tasks planned for this date
        let plannedTasks = tasks.filter { task in
            guard let plannedDate = task.plannedWorkDate else { return false }
            return DateUtils.isSameDay(plannedDate, date, timeZone: timeZone)
        }

        return plannedTasks.reduce(0) { sum, task in
            sum + effortForScheduling(task)
        }
    }

    /// Get task's effort for scheduling (use actual or estimated)
    static func effortForScheduling(_ task: Task) -> Int {
        return task.effortForScheduling()
    }

    // MARK: - Study Capacity

    /// Calculate available study capacity after busy time
    static func studyCapacityMin(on date: Date, profile: UserProfile, events: [Event], timeZone: TimeZone = .current) -> Int {
        let capacity = capacityMin(for: date, profile: profile, timeZone: timeZone)
        if capacity == 0 { return 0 }

        let busy = busyMin(on: date, events: events, timeZone: timeZone)
        return max(capacity - busy, 0)
    }

    // MARK: - Load Ratio

    /// Calculate load ratio (task load / study capacity)
    static func loadRatio(on date: Date, profile: UserProfile, tasks: [Task], events: [Event], timeZone: TimeZone = .current) -> Double {
        let load = loadMin(on: date, tasks: tasks, timeZone: timeZone)
        let capacity = studyCapacityMin(on: date, profile: profile, events: events, timeZone: timeZone)

        if capacity <= 0 {
            return load > 0 ? Double.infinity : 0
        }

        return Double(load) / Double(capacity)
    }

    // MARK: - Capacity Check

    /// Check if adding a task would exceed capacity
    static func wouldExceedCapacity(
        on date: Date,
        addingTaskWithEffort effort: Int,
        profile: UserProfile,
        tasks: [Task],
        events: [Event],
        timeZone: TimeZone = .current
    ) -> Bool {
        let currentLoad = loadMin(on: date, tasks: tasks, timeZone: timeZone)
        let newLoad = currentLoad + effort
        let capacity = studyCapacityMin(on: date, profile: profile, events: events, timeZone: timeZone)

        if capacity <= 0 { return true }

        let newRatio = Double(newLoad) / Double(capacity)
        return newRatio > MAX_DAY_OVERLOAD_RATIO
    }

    // MARK: - Capacity vs Deadline Conflict

    /// Check if there's a capacity-deadline conflict on a specific date
    static func checkCapacityDeadlineConflict(
        on date: Date,
        profile: UserProfile,
        tasks: [Task],
        events: [Event],
        timeZone: TimeZone = .current
    ) -> (hasConflict: Bool, message: String?) {
        let capacity = capacityMin(for: date, profile: profile, timeZone: timeZone)

        guard capacity == 0 else { return (false, nil) }

        // Find tasks with deadline on this date
        let dateKey = DateUtils.formatDateKey(date, timeZone: timeZone)
        let deadlineTasks = tasks.filter { task in
            task.state == .open &&
            task.deletedAt == nil &&
            task.deadlineDate == dateKey
        }

        guard !deadlineTasks.isEmpty else { return (false, nil) }

        let taskTitles = deadlineTasks.prefix(3).map { "「\($0.title)」" }.joined(separator: "、")
        let moreCount = max(deadlineTasks.count - 3, 0)
        let moreText = moreCount > 0 ? "等 \(moreCount) 個" : ""

        let dateStr = DateUtils.formatDisplayDate(date, timeZone: timeZone)
        let message = "⚠️ \(dateStr) 你設定容量為 0，但有 \(taskTitles)\(moreText) 在這天到期"

        return (true, message)
    }

    // MARK: - Week Load Summary

    struct WeekLoadSummary {
        var avgRatio: Double
        var hardDays: Int      // days with ratio > 1.3
        var lightDays: Int     // days with ratio < 0.5
        var mood: String
        var suggestion: String
    }

    /// Get week load summary
    static func weekLoadSummary(
        weekStart: Date,
        profile: UserProfile,
        tasks: [Task],
        events: [Event],
        timeZone: TimeZone = .current
    ) -> WeekLoadSummary {
        var ratios: [Double] = []

        for i in 0..<7 {
            let date = DateUtils.addDays(weekStart, i, timeZone: timeZone)
            let ratio = loadRatio(on: date, profile: profile, tasks: tasks, events: events, timeZone: timeZone)
            ratios.append(ratio == .infinity ? 2.0 : ratio) // Cap infinity at 2.0 for averaging
        }

        let avgRatio = ratios.reduce(0, +) / Double(ratios.count)
        let hardDays = ratios.filter { $0 > 1.3 }.count
        let lightDays = ratios.filter { $0 < 0.5 }.count

        let mood: String
        let suggestion: String

        if avgRatio < 0.9 && hardDays == 0 {
            mood = "🙂"
            suggestion = "這週還很鬆，可以從 Backlog 挑一兩顆重要的進來。"
        } else if avgRatio <= 1.4 && hardDays <= 2 {
            mood = "😐"
            suggestion = "這週看起來在可控範圍內，維持這個節奏就好。"
        } else {
            mood = "😵"
            suggestion = "這週有好幾天可能太硬，試試把一些任務延到下週。"
        }

        return WeekLoadSummary(
            avgRatio: avgRatio,
            hardDays: hardDays,
            lightDays: lightDays,
            mood: mood,
            suggestion: suggestion
        )
    }

    // MARK: - Load Level Description

    enum LoadLevel {
        case light    // < 0.7
        case normal   // 0.7 - 1.0
        case busy     // 1.0 - 1.3
        case heavy    // 1.3 - 1.8
        case overload // > 1.8

        var emoji: String {
            switch self {
            case .light: return "🙂"
            case .normal: return "😐"
            case .busy: return "😅"
            case .heavy: return "😰"
            case .overload: return "😵"
            }
        }

        var description: String {
            switch self {
            case .light: return "輕鬆"
            case .normal: return "適中"
            case .busy: return "忙碌"
            case .heavy: return "很硬"
            case .overload: return "爆炸"
            }
        }

        var color: String {
            switch self {
            case .light: return "#10B981"    // green
            case .normal: return "#3B82F6"   // blue
            case .busy: return "#F59E0B"     // amber
            case .heavy: return "#EF4444"    // red
            case .overload: return "#DC2626" // dark red
            }
        }
    }

    /// Get load level for a ratio
    static func loadLevel(for ratio: Double) -> LoadLevel {
        if ratio < 0.7 {
            return .light
        } else if ratio < 1.0 {
            return .normal
        } else if ratio < 1.3 {
            return .busy
        } else if ratio < 1.8 {
            return .heavy
        } else {
            return .overload
        }
    }
}
