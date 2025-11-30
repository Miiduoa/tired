import Foundation
import FirebaseFirestoreSwift

// MARK: - Task Conflict Models

/// 任务冲突严重程度
enum ConflictSeverity: String, Codable, Comparable {
    case warning   // 2个任务冲突
    case severe    // 3个或以上任务冲突
    case critical  // 多个高优先级任务同时冲突

    static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        let order: [ConflictSeverity] = [.warning, .severe, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false // Should not happen if all cases are in the array
        }
        return lhsIndex < rhsIndex
    }

    var displayName: String {
        switch self {
        case .warning: return "警告"
        case .severe: return "严重"
        case .critical: return "紧急"
        }
    }

    var emoji: String {
        switch self {
        case .warning: return "⚠️"
        case .severe: return "🚨"
        case .critical: return "🔴"
        }
    }
}

/// 任务时间范围
struct TaskTimeRange {
    let task: Task
    let startTime: Date
    let endTime: Date

    /// 检查与另一个任务是否有时间重叠
    func overlaps(with other: TaskTimeRange) -> Bool {
        return !(endTime <= other.startTime || startTime >= other.endTime)
    }

    /// 检查与课程时间是否重叠
    func overlaps(with courseRange: CourseTimeRange) -> Bool {
        return !(endTime <= courseRange.startTime || startTime >= courseRange.endTime)
    }
}

/// 课程时间范围
struct CourseTimeRange {
    let schedule: CourseSchedule
    let startTime: Date
    let endTime: Date

    /// 检查与任务时间是否重叠
    func overlaps(with taskRange: TaskTimeRange) -> Bool {
        return !(endTime <= taskRange.startTime || startTime >= taskRange.endTime)
    }
}

/// 检测到的任务冲突
struct TaskConflict: Identifiable {
    var id: String {
        let taskIds = conflictingTaskIds.joined(separator: "-")
        let courseIds = conflictingCourseIds.joined(separator: "-")
        return taskIds + (courseIds.isEmpty ? "" : "-course-\(courseIds)")
    }

    /// 冲突涉及的任务
    let conflictingTasks: [Task]

    /// 冲突涉及的课程（新增）
    let conflictingCourses: [CourseSchedule]

    /// 冲突的任务 ID
    var conflictingTaskIds: [String] {
        conflictingTasks.compactMap { $0.id }
    }

    /// 冲突的课程 ID（新增）
    var conflictingCourseIds: [String] {
        conflictingCourses.compactMap { $0.id }
    }

    /// 冲突发生的时间范围
    let startTime: Date
    let endTime: Date

    /// 冲突严重程度
    let severity: ConflictSeverity

    /// 冲突持续时间（分钟）
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    /// 涉及的组织
    var involvedOrganizations: [String] {
        var orgs = conflictingTasks.compactMap { $0.sourceOrgId }
        orgs.append(contentsOf: conflictingCourses.map { $0.organizationId })
        return Array(Set(orgs))
    }

    /// 是否包含课程冲突
    var hasCourseConflict: Bool {
        !conflictingCourses.isEmpty
    }

    /// 用户友好的描述
    var description: String {
        var items: [String] = conflictingTasks.map { $0.title }

        if !conflictingCourses.isEmpty {
            items.append(contentsOf: conflictingCourses.map { course in
                "课程时间 (\(course.startTime)-\(course.endTime))"
            })
        }

        let itemsStr = items.joined(separator: "、")
        let timeStr = startTime.formatted(date: .omitted, time: .shortened)
        return "\(severity.emoji) \(itemsStr) 在 \(timeStr) 冲突"
    }

    // 便利初始化器（保持向后兼容）
    init(
        conflictingTasks: [Task],
        conflictingCourses: [CourseSchedule] = [],
        startTime: Date,
        endTime: Date,
        severity: ConflictSeverity
    ) {
        self.conflictingTasks = conflictingTasks
        self.conflictingCourses = conflictingCourses
        self.startTime = startTime
        self.endTime = endTime
        self.severity = severity
    }
}

// MARK: - Task Conflict Detector Service

/// 任务冲突检测服务
class TaskConflictDetector {

    /// 在给定时间范围内检测所有冲突
    /// - Parameters:
    ///   - tasks: 要检查的任务列表
    ///   - startDate: 检查的开始日期
    ///   - endDate: 检查的结束日期
    /// - Returns: 检测到的所有冲突
    func detectConflicts(
        tasks: [Task],
        startDate: Date,
        endDate: Date
    ) -> [TaskConflict] {
        // 构建任务时间范围列表（只包括在时间范围内且未完成的任务）
        let timeRanges = tasks
            .filter { task in
                !task.isDone &&
                task.estimatedMinutes != nil &&
                (task.estimatedMinutes ?? 0) > 0
            }
            .compactMap { task -> TaskTimeRange? in
                // 使用 plannedDate 或 deadlineAt
                let taskDate = task.plannedDate ?? task.deadlineAt
                guard let taskDate = taskDate else { return nil }

                // 检查任务是否在时间范围内
                guard taskDate >= startDate && taskDate < endDate else { return nil }

                let endTime = taskDate.addingTimeInterval(TimeInterval((task.estimatedMinutes ?? 60) * 60))
                return TaskTimeRange(task: task, startTime: taskDate, endTime: endTime)
            }

        // 检测冲突
        var conflicts: [TaskConflict] = []
        var processedTaskIds: Set<String> = []

        for (index, range) in timeRanges.enumerated() {
            let taskId = range.task.id ?? ""
            guard !processedTaskIds.contains(taskId) else { continue }

            // 找到所有与此任务冲突的任务
            var conflictingRanges = [range]

            for otherRange in timeRanges[(index + 1)...] {
                if range.overlaps(with: otherRange) {
                    conflictingRanges.append(otherRange)
                }
            }

            // 如果有冲突，记录这个冲突组
            if conflictingRanges.count > 1 {
                let conflictingTasks = conflictingRanges.map { $0.task }
                let severity = calculateSeverity(for: conflictingTasks, ranges: conflictingRanges)

                // 找到这个冲突组的时间范围
                guard let overlapStart = conflictingRanges.map({ $0.startTime }).max(),
                      let overlapEnd = conflictingRanges.map({ $0.endTime }).min() else {
                    continue // Should not happen if conflictingRanges.count > 1
                }

                let conflict = TaskConflict(
                    conflictingTasks: conflictingTasks,
                    startTime: overlapStart,
                    endTime: overlapEnd,
                    severity: severity
                )

                conflicts.append(conflict)

                // 标记这些任务已处理
                conflictingTasks.forEach { task in
                    processedTaskIds.insert(task.id ?? "")
                }
            }
        }

        // 按严重程度排序
        return conflicts.sorted { $0.severity > $1.severity }
    }

    /// 检测用户本周的所有冲突
    /// - Parameter tasks: 任务列表
    /// - Returns: 本周的所有冲突
    func detectWeeklyConflicts(tasks: [Task]) -> [TaskConflict] {
        let calendar = Calendar.current
        let now = Date()

        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now.addingTimeInterval(7 * 24 * 60 * 60)

        return detectConflicts(tasks: tasks, startDate: weekStart, endDate: weekEnd)
    }

    /// 检测今天的所有冲突
    /// - Parameter tasks: 任务列表
    /// - Returns: 今天的所有冲突
    func detectTodayConflicts(tasks: [Task]) -> [TaskConflict] {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? today.addingTimeInterval(24 * 60 * 60)

        return detectConflicts(tasks: tasks, startDate: todayStart, endDate: tomorrowStart)
    }

    /// 检查插入新任务是否会产生冲突
    /// - Parameters:
    ///   - newTask: 新任务
    ///   - existingTasks: 现有任务列表
    /// - Returns: 如果有冲突返回冲突信息，否则返回 nil
    func checkInsertionConflicts(
        newTask: Task,
        into existingTasks: [Task]
    ) -> [TaskConflict] {
        var allTasks = existingTasks
        var mutableNewTask = newTask
        mutableNewTask.id = UUID().uuidString  // 临时 ID
        allTasks.append(mutableNewTask)

        guard let startDate = newTask.plannedDate ?? newTask.deadlineAt else {
            return []
        }

        let endDate = startDate.addingTimeInterval(TimeInterval((newTask.estimatedMinutes ?? 60) * 60))

        return detectConflicts(tasks: allTasks, startDate: startDate, endDate: endDate)
    }

    /// 获取冲突摘要（用于显示通知或警告）
    /// - Parameter conflicts: 冲突列表
    /// - Returns: 简短的冲突摘要
    func getConflictSummary(_ conflicts: [TaskConflict]) -> String {
        if conflicts.isEmpty {
            return "没有时间冲突 ✅"
        }

        let criticalConflicts = conflicts.filter { $0.severity == .critical }
        let severeConflicts = conflicts.filter { $0.severity == .severe }
        let warningConflicts = conflicts.filter { $0.severity == .warning }

        var summary = ""
        if !criticalConflicts.isEmpty {
            summary += "🔴 \(criticalConflicts.count) 个紧急冲突 "
        }
        if !severeConflicts.isEmpty {
            summary += "🚨 \(severeConflicts.count) 个严重冲突 "
        }
        if !warningConflicts.isEmpty {
            summary += "⚠️ \(warningConflicts.count) 个冲突"
        }

        return summary.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Course Schedule Conflict Detection

    /// 检测任务与课程时间表的冲突
    /// - Parameters:
    ///   - tasks: 任务列表
    ///   - courseSchedules: 课程时间表列表
    ///   - startDate: 检查的开始日期
    ///   - endDate: 检查的结束日期
    /// - Returns: 检测到的所有冲突
    func detectConflictsWithCourses(
        tasks: [Task],
        courseSchedules: [CourseSchedule],
        startDate: Date,
        endDate: Date
    ) -> [TaskConflict] {
        // 构建任务时间范围列表
        let taskRanges = tasks
            .filter { task in
                !task.isDone &&
                task.estimatedMinutes != nil &&
                (task.estimatedMinutes ?? 0) > 0
            }
            .compactMap { task -> TaskTimeRange? in
                let taskDate = task.plannedDate ?? task.deadlineAt
                guard let taskDate = taskDate else { return nil }
                guard taskDate >= startDate && taskDate < endDate else { return nil }

                let endTime = taskDate.addingTimeInterval(TimeInterval((task.estimatedMinutes ?? 60) * 60))
                return TaskTimeRange(task: task, startTime: taskDate, endTime: endTime)
            }

        // 构建课程时间范围列表（针对检查期间的每一周）
        var courseRanges: [CourseTimeRange] = []
        let calendar = Calendar.current

        var currentDate = startDate
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)

            // 查找当天的课程
            let todayCourses = courseSchedules.filter { $0.dayOfWeek == weekday }

            for course in todayCourses {
                if let courseStart = parseTimeString(course.startTime, on: currentDate),
                   let courseEnd = parseTimeString(course.endTime, on: currentDate) {
                    let courseRange = CourseTimeRange(
                        schedule: course,
                        startTime: courseStart,
                        endTime: courseEnd
                    )
                    courseRanges.append(courseRange)
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        // 检测任务与课程的冲突
        var conflicts: [TaskConflict] = []

        for taskRange in taskRanges {
            var conflictingCourses: [CourseSchedule] = []

            for courseRange in courseRanges {
                if taskRange.overlaps(with: courseRange) {
                    conflictingCourses.append(courseRange.schedule)
                }
            }

            // 如果有冲突，创建冲突记录
            if !conflictingCourses.isEmpty {
                // 课程冲突通常是严重的，因为课程时间是固定的
                let severity: ConflictSeverity = taskRange.task.priority == .high ? .critical : .severe

                let conflict = TaskConflict(
                    conflictingTasks: [taskRange.task],
                    conflictingCourses: conflictingCourses,
                    startTime: taskRange.startTime,
                    endTime: taskRange.endTime,
                    severity: severity
                )

                conflicts.append(conflict)
            }
        }

        return conflicts.sorted { $0.severity > $1.severity }
    }

    /// 检查新任务是否与课程时间表冲突
    /// - Parameters:
    ///   - newTask: 新任务
    ///   - courseSchedules: 课程时间表列表
    /// - Returns: 如果有冲突返回冲突信息
    func checkTaskCourseConflicts(
        newTask: Task,
        courseSchedules: [CourseSchedule]
    ) -> [TaskConflict] {
        guard let taskDate = newTask.plannedDate ?? newTask.deadlineAt else {
            return []
        }

        let taskEnd = taskDate.addingTimeInterval(TimeInterval((newTask.estimatedMinutes ?? 60) * 60))

        return detectConflictsWithCourses(
            tasks: [newTask],
            courseSchedules: courseSchedules,
            startDate: taskDate,
            endDate: taskEnd
        )
    }

    /// 解析时间字符串（"HH:mm"）为特定日期的Date对象
    private func parseTimeString(_ timeString: String, on date: Date) -> Date? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(from: dateComponents)
    }

    /// 为冲突任务提供解决建议
    /// - Parameter conflict: 冲突信息
    /// - Returns: 解决建议列表
    func getSuggestions(for conflict: TaskConflict) -> [String] {
        var suggestions: [String] = []

        // 如果与课程冲突，优先提示调整任务时间
        if conflict.hasCourseConflict {
            suggestions.append("📚 任务与课程时间冲突，课程时间通常是固定的，建议调整任务的计划时间")

            if !conflict.conflictingCourses.isEmpty {
                let courseInfo = conflict.conflictingCourses.map { course in
                    "\(course.startTime)-\(course.endTime)"
                }.joined(separator: "、")
                suggestions.append("🕐 课程时间: \(courseInfo)")
            }

            // 如果只有任务，不涉及其他任务冲突
            if conflict.conflictingTasks.count == 1, let task = conflict.conflictingTasks.first {
                suggestions.append("💡 建议将\"\(task.title)\"移到课程之前或之后的时段")
            }

            return suggestions
        }

        // 按优先级排序任务（原有的任务冲突逻辑）
        let sortedTasks = conflict.conflictingTasks.sorted { t1, t2 in
            if t1.priority.hierarchyValue != t2.priority.hierarchyValue {
                return t1.priority.hierarchyValue > t2.priority.hierarchyValue
            }
            // 优先级相同，按 deadline 排序
            if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                return d1 < d2
            }
            return t1.deadlineAt != nil
        }

        // 找到最低优先级的任务
        if let lowestPriorityTask = sortedTasks.last {
            suggestions.append("💡 建议将\"\(lowestPriorityTask.title)\"移到其他时间")
        }

        // 检查是否有任务是来自同一个组织的
        let orgIds = conflict.involvedOrganizations
        if orgIds.count > 1 {
            suggestions.append("📋 您在\(conflict.conflictingTasks.count)个组织中有冲突的任务，建议与相关负责人协调")
        }

        // 检查是否可以缩短某些任务的预估时间
        let longestTask = conflict.conflictingTasks.max { t1, t2 in
            (t1.estimatedMinutes ?? 0) < (t2.estimatedMinutes ?? 0)
        }
        if let longestTask = longestTask, longestTask.estimatedMinutes ?? 0 > 60 {
            suggestions.append("⏱️ 建议重新评估\"\(longestTask.title)\"的预估时长")
        }

        return suggestions
    }

    // MARK: - Private Helper Methods

    /// 计算冲突的严重程度
    private func calculateSeverity(
        for tasks: [Task],
        ranges: [TaskTimeRange]
    ) -> ConflictSeverity {
        // 如果是 3 个或以上任务冲突，标记为严重
        if tasks.count >= 3 {
            // 检查是否有多个高优先级任务
            let highPriorityCount = tasks.filter { $0.priority == .high }.count
            if highPriorityCount >= 2 {
                return .critical
            }
            return .severe
        }

        // 2 个任务冲突，标记为警告
        return .warning
    }
}
