import Foundation

/// 自動排程服務 - 智能任務分配演算法
class AutoPlanService {

    /// 自動排程選項
    struct AutoPlanOptions {
        let weekStart: Date
        let weeklyCapacityMinutes: Int
        let dailyCapacityMinutes: Int
        let workdaysInWeek: Int
        let workdayIndices: Set<Int>  // 0=週日, 1=週一, ..., 6=週六
        let allowWeekends: Bool
        let priorityWeights: [TaskPriority: Double]

        init(
            weekStart: Date? = nil,
            weeklyCapacityMinutes: Int = 600,  // 預設10小時/週
            dailyCapacityMinutes: Int? = nil,
            workdaysInWeek: Int = 5,
            workdayIndices: Set<Int>? = nil,  // 自定義工作日
            allowWeekends: Bool = false,
            priorityWeights: [TaskPriority: Double]? = nil
        ) {
            let calendar = Calendar.current
            self.weekStart = weekStart ?? calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            self.weeklyCapacityMinutes = weeklyCapacityMinutes
            self.workdaysInWeek = max(1, min(7, workdaysInWeek))
            self.allowWeekends = allowWeekends

            // 設定工作日索引（預設週一到週五）
            if let indices = workdayIndices {
                self.workdayIndices = indices
            } else {
                // 預設：週一(2)到週五(6)，使用 Calendar.current.firstWeekday 調整
                self.workdayIndices = Set([2, 3, 4, 5, 6]) // 1=週日, 2=週一, ...
            }

            // 設定優先級權重
            self.priorityWeights = priorityWeights ?? [
                .high: 3.0,
                .medium: 2.0,
                .low: 1.0
            ]

            if let dailyCapacityMinutes {
                self.dailyCapacityMinutes = dailyCapacityMinutes
            } else {
                self.dailyCapacityMinutes = weeklyCapacityMinutes / self.workdaysInWeek
            }
        }
    }

    /// 為本週任務進行自動排程
    /// - Parameters:
    ///   - tasks: 所有任務（包括已排程和未排程）
    ///   - options: 排程選項
    /// - Returns: 更新後的任務列表和實際排程的任務數量
    func autoplanWeek(tasks: [Task], busyBlocks: [BusyTimeBlock] = [], options: AutoPlanOptions) -> ([Task], Int) {
        let calendar = Calendar.current
        var updatedTasks = tasks
        var scheduledTaskCount = 0
        let today = calendar.startOfDay(for: Date())

        // 1. 篩選候選任務（未完成、未鎖定、未排程）
        let candidates = tasks
            .filter { task in
                !task.isDone &&
                !task.isDateLocked &&
                task.plannedDate == nil
            }
            .sorted { t1, t2 in
                // ✅ 改进排序逻辑：优先级 > Deadline > 创建时间

                // 第一步：按优先级排序 (high > medium > low)
                let priorityOrder: [TaskPriority] = [.high, .medium, .low]
                if let p1 = priorityOrder.firstIndex(of: t1.priority),
                   let p2 = priorityOrder.firstIndex(of: t2.priority),
                   p1 != p2 {
                    return p1 < p2  // 优先级高的排前面
                }

                // 第二步：优先级相同，按 deadline 排序
                if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                    return d1 < d2
                }
                if t1.deadlineAt != nil { return true }
                if t2.deadlineAt != nil { return false }

                // 第三步：都没有 deadline，按创建时间
                return t1.createdAt < t2.createdAt
            }

        // 2. 計算每天已排程的時間（只計算今天及之後的日期）
        var dayMinutes: [Date: Int] = [:]
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: options.weekStart) ?? options.weekStart
        
        // 先加上外部日曆的忙碌時間
        for block in busyBlocks {
            let startDay = calendar.startOfDay(for: block.start)
            let endDay = calendar.startOfDay(for: block.end)
            
            if startDay == endDay {
                // 單日事件
                let duration = Int(block.end.timeIntervalSince(block.start) / 60)
                dayMinutes[startDay, default: 0] += duration
            } else {
                // 跨日事件
                var currentDay = startDay
                while currentDay <= endDay {
                    let dayStart = currentDay
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
                    
                    let intersectionStart = max(block.start, dayStart)
                    let intersectionEnd = min(block.end, dayEnd)
                    
                    if intersectionEnd > intersectionStart {
                        let duration = Int(intersectionEnd.timeIntervalSince(intersectionStart) / 60)
                        dayMinutes[currentDay, default: 0] += duration
                    }
                    
                    currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? (currentDay + 86400)
                }
            }
        }

        for task in tasks {
            guard let planned = task.plannedDate,
                  !task.isDone else { continue }  // ✅ 只计算未完成任务
            let plannedDay = calendar.startOfDay(for: planned)

            // 只計算本週範圍內的任務
            if plannedDay >= options.weekStart && plannedDay < weekEnd {
                dayMinutes[plannedDay, default: 0] += task.estimatedMinutes ?? 0
            }
        }

        // 3. 生成可用日期列表（今天及之後的工作日）
        var availableDays: [Date] = []
        for offset in 0..<14 {  // 考慮未來兩週
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            let weekday = calendar.component(.weekday, from: date)
            let isWorkday = options.workdayIndices.contains(weekday)
            let isWeekend = weekday == 1 || weekday == 7  // 週日或週六

            // 跳過非工作日（除非允許週末）
            if !isWorkday && !(options.allowWeekends && isWeekend) {
                continue
            }

            availableDays.append(date)
        }

        // 4. 為候選任務分配日期
        for candidate in candidates {
            let duration = candidate.estimatedMinutes ?? 60  // 預設1小時

            // 計算截止日期約束
            let deadlineDate: Date? = candidate.deadlineAt.map { calendar.startOfDay(for: $0) }

            // 找到最適合的日期
            var bestDay: Date? = nil
            var bestScore: Double = Double.infinity

            for day in availableDays {
                // 跳過已超過截止日期的日子
                if let deadline = deadlineDate, day > deadline {
                    continue
                }

                let currentLoad = dayMinutes[day, default: 0]
                let newLoad = currentLoad + duration

                // 跳過已超載的日子
                if newLoad > options.dailyCapacityMinutes * 12 / 10 {  // 允許10%彈性
                    continue
                }

                // 計算分數（越低越好）
                var score: Double = Double(currentLoad)  // 負載越低越好

                // 考慮截止日期緊迫性
                if let deadline = deadlineDate {
                    let daysUntilDeadline = calendar.dateComponents([.day], from: day, to: deadline).day ?? 0
                    if daysUntilDeadline <= 1 {
                        score -= 1000  // 緊急任務優先安排
                    } else if daysUntilDeadline <= 3 {
                        score -= 500
                    }
                }

                // 優先安排高優先級任務到較早的日期
                let dayOffset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
                let priorityWeight = options.priorityWeights[candidate.priority] ?? 1.0
                if priorityWeight >= 3.0 {
                    score += Double(dayOffset) * 10  // 高優先級任務盡量安排到早期
                }

                if score < bestScore {
                    bestScore = score
                    bestDay = day
                }
            }

            // 如果沒找到合適的日子，選擇負載最低的日子
            if bestDay == nil {
                bestDay = availableDays
                    .filter { day in
                        if let deadline = deadlineDate { return day <= deadline }
                        return true
                    }
                    .min { dayMinutes[$0, default: 0] < dayMinutes[$1, default: 0] }
            }

            // 更新任務
            if let assignedDay = bestDay,
               let taskIndex = updatedTasks.firstIndex(where: { $0.id == candidate.id }) {
                dayMinutes[assignedDay, default: 0] += duration
                updatedTasks[taskIndex].plannedDate = assignedDay
                updatedTasks[taskIndex].isDateLocked = false
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
