import Foundation

/// 自动排程服务
class AutoPlanService {

    /// 自动排程选项
    struct AutoPlanOptions {
        let weekStart: Date
        let weeklyCapacityMinutes: Int
        let dailyCapacityMinutes: Int // Calculated based on weeklyCapacity and workdaysInWeek
        let workdaysInWeek: Int // New property: Number of days considered workdays for daily capacity calculation

        init(
            weekStart: Date? = nil,
            weeklyCapacityMinutes: Int = 600,  // 默认10小时/周
            dailyCapacityMinutes: Int? = nil,
            workdaysInWeek: Int = 5 // Default to 5 workdays
        ) {
            let calendar = Calendar.current
            self.weekStart = weekStart ?? calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            self.weeklyCapacityMinutes = weeklyCapacityMinutes
            self.workdaysInWeek = max(1, workdaysInWeek) // Ensure at least 1 workday
            if let dailyCapacityMinutes {
                self.dailyCapacityMinutes = dailyCapacityMinutes
            } else {
                self.dailyCapacityMinutes = weeklyCapacityMinutes / self.workdaysInWeek
            }
        }
    }

    /// 为本周任务进行自动排程
    /// - Parameters:
    ///   - tasks: 所有任务（包括已排程和未排程）
    ///   - options: 排程选项
    /// - Returns: 更新后的任务列表和实际排程的任务数量
    func autoplanWeek(tasks: [Task], options: AutoPlanOptions) -> ([Task], Int) {
        let calendar = Calendar.current
        var updatedTasks = tasks
        var scheduledTaskCount = 0

        // 1. 筛选候选任务（未完成、未锁定、未排程）
        let candidates = tasks
            .filter { task in
                !task.isDone &&
                !task.isDateLocked &&
                task.plannedDate == nil
            }
            .sorted { t1, t2 in
                // 按deadline排序，没有deadline的排后面
                if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                    return d1 < d2
                }
                if t1.deadlineAt != nil { return true }
                if t2.deadlineAt != nil { return false }
                return t1.createdAt < t2.createdAt
            }

        // 2. 计算每天已排程的时间
        var dayMinutes: [Int] = Array(repeating: 0, count: 7)

        for task in tasks {
            guard let planned = task.plannedDate else { continue }

            let dayIndex = calendar.dateComponents([.day], from: calendar.startOfDay(for: options.weekStart), to: calendar.startOfDay(for: planned)).day ?? -1
            if dayIndex >= 0 && dayIndex < 7 {
                dayMinutes[dayIndex] += task.estimatedMinutes ?? 0
            }
        }

        // 3. 为候选任务分配日期
        for candidate in candidates {
            let duration = candidate.estimatedMinutes ?? 60  // 默认1小时

            // 找到最空闲的一天
            var assignedIndex: Int? = nil

            // 优先从今天开始找
            let today = Date()
            let todayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: options.weekStart), to: calendar.startOfDay(for: today)).day ?? 0

            // Iterate through days, respecting workdays
            for offset in 0..<7 {
                let dayIndex = (todayOffset + offset) % 7
                
                // Only consider workdays for autoplan
                // This is a simplification; a more advanced version would check if dayIndex corresponds to a workday based on user settings
                // For now, assume 0-4 (Monday-Friday) are workdays if workdaysInWeek is 5.
                // This needs more robust configuration if users can customize specific workdays.
                if options.workdaysInWeek == 5 && (dayIndex == 5 || dayIndex == 6) { // Skip Saturday (5) and Sunday (6) if 5 workdays
                    continue
                }

                if dayMinutes[dayIndex] + duration <= options.dailyCapacityMinutes {
                    assignedIndex = dayIndex
                    break
                }
            }
            
            // If no suitable workday found, try to assign to the least loaded day regardless of workday status
            if assignedIndex == nil {
                assignedIndex = dayMinutes.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            }


            // Update task
            if let index = assignedIndex,
               let plannedDate = calendar.date(byAdding: .day, value: index, to: options.weekStart),
               let taskIndex = updatedTasks.firstIndex(where: { $0.id == candidate.id }) {
                dayMinutes[index] += duration
                updatedTasks[taskIndex].plannedDate = plannedDate
                updatedTasks[taskIndex].isDateLocked = false // Autoplan should not lock the date
                scheduledTaskCount += 1
            }
        }

        return (updatedTasks, scheduledTaskCount)
    }

    /// 计算每日任务总时长
    func calculateDailyDuration(tasks: [Task], for date: Date) -> Int {
        let calendar = Calendar.current

        return tasks
            .filter { task in
                guard let planned = task.plannedDate else { return false }
                return calendar.isDate(planned, equalTo: date, toGranularity: .day)
            }
            .reduce(0) { sum, task in
                sum + (task.estimatedMinutes ?? 0)
            }
    }

    /// 检查某天是否超载
    func isOverloaded(tasks: [Task], for date: Date, capacity: Int) -> Bool {
        calculateDailyDuration(tasks: tasks, for: date) > capacity
    }

    /// 获取本周每天的负载情况
    func getWeeklyLoad(tasks: [Task], weekStart: Date) -> [Int] {
        let calendar = Calendar.current
        var loads: [Int] = Array(repeating: 0, count: 7)

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekStart) {
                loads[i] = calculateDailyDuration(tasks: tasks, for: date)
            }
        }

        return loads
    }
}
