import Foundation

/// 自动排程服务
class AutoPlanService {

    /// 自动排程选项
    struct AutoPlanOptions {
        let weekStart: Date
        let weeklyCapacityMinutes: Int
        let dailyCapacityMinutes: Int

        init(
            weekStart: Date? = nil,
            weeklyCapacityMinutes: Int = 600  // 默认10小时/周
        ) {
            let calendar = Calendar.current
            self.weekStart = weekStart ?? calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            self.weeklyCapacityMinutes = weeklyCapacityMinutes
            self.dailyCapacityMinutes = weeklyCapacityMinutes / 5  // 假设5个工作日
        }
    }

    /// 为本周任务进行自动排程
    /// - Parameters:
    ///   - tasks: 所有任务（包括已排程和未排程）
    ///   - options: 排程选项
    /// - Returns: 更新后的任务列表
    func autoplanWeek(tasks: [Task], options: AutoPlanOptions) -> [Task] {
        let calendar = Calendar.current
        var updatedTasks = tasks

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

            if let dayIndex = calendar.dateComponents([.day], from: options.weekStart, to: planned).day,
               dayIndex >= 0 && dayIndex < 7 {
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
            let todayOffset = calendar.dateComponents([.day], from: options.weekStart, to: today).day ?? 0

            for offset in 0..<7 {
                let dayIndex = (todayOffset + offset) % 7
                guard dayIndex >= 0 && dayIndex < 7 else { continue }

                if dayMinutes[dayIndex] + duration <= options.dailyCapacityMinutes {
                    assignedIndex = dayIndex
                    break
                }
            }

            // 如果没找到合适的，就分配到最空的那天
            if assignedIndex == nil {
                assignedIndex = dayMinutes.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            }

            // 更新任务
            if let index = assignedIndex {
                dayMinutes[index] += duration

                let plannedDate = calendar.date(byAdding: .day, value: index, to: options.weekStart)

                if let taskIndex = updatedTasks.firstIndex(where: { $0.id == candidate.id }) {
                    updatedTasks[taskIndex].plannedDate = plannedDate
                    updatedTasks[taskIndex].isDateLocked = false
                }
            }
        }

        return updatedTasks
    }

    /// 计算每日任务总时长
    func calculateDailyDuration(tasks: [Task], for date: Date) -> Int {
        let calendar = Calendar.current

        return tasks
            .filter { task in
                guard let planned = task.plannedDate else { return false }
                return calendar.isDate(planned, inSameDayAs: date)
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
