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
        let dependencyService = TaskDependencyService()

        // 1. 篩選候選任務（未完成、未鎖定、未排程）
        let candidates = dependencyService.topologicalSort(
            tasks.filter { task in
                !task.isDone &&
                !task.isDateLocked &&
                task.plannedDate == nil
            },
            preferPriority: true
        )

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
    
    // MARK: - 智能排程建議
    
    /// 自動排程報告
    struct AutoPlanReport {
        let scheduledTasks: [Task]
        let skippedTasks: [(task: Task, reason: String)]
        let overloadedDays: [Date]
        let totalScheduledMinutes: Int
        let suggestions: [String]
    }
    
    /// 進行自動排程並生成報告
    func autoplanWithReport(tasks: [Task], busyBlocks: [BusyTimeBlock] = [], options: AutoPlanOptions) -> AutoPlanReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: options.weekStart) ?? options.weekStart
        
        var scheduledTasks: [Task] = []
        var skippedTasks: [(task: Task, reason: String)] = []
        var overloadedDays: [Date] = []
        var suggestions: [String] = []
        var totalScheduledMinutes = 0
        
        // 執行排程
        let (updatedTasks, scheduledCount) = autoplanWeek(tasks: tasks, busyBlocks: busyBlocks, options: options)
        
        // 分析結果
        for task in updatedTasks {
            if task.plannedDate != nil && !task.isDone && !task.isDateLocked {
                if let original = tasks.first(where: { $0.id == task.id }),
                   original.plannedDate == nil {
                    scheduledTasks.append(task)
                    totalScheduledMinutes += task.estimatedMinutes ?? 60
                }
            }
        }
        
        // 檢查被跳過的任務
        let candidates = tasks.filter { !$0.isDone && !$0.isDateLocked && $0.plannedDate == nil }
        for candidate in candidates {
            let wasScheduled = scheduledTasks.contains { $0.id == candidate.id }
            if !wasScheduled {
                var reason = "無法找到合適的時間段"
                
                if let deadline = candidate.deadlineAt, deadline < today {
                    reason = "截止日期已過期"
                } else if (candidate.estimatedMinutes ?? 0) > options.dailyCapacityMinutes {
                    reason = "預估時間超過每日容量"
                }
                
                skippedTasks.append((candidate, reason))
            }
        }
        
        // 檢查超載的日期
        var dayMinutes: [Date: Int] = [:]
        for task in updatedTasks {
            guard let planned = task.plannedDate, !task.isDone else { continue }
            let plannedDay = calendar.startOfDay(for: planned)
            if plannedDay >= options.weekStart && plannedDay < weekEnd {
                dayMinutes[plannedDay, default: 0] += task.estimatedMinutes ?? 0
            }
        }
        
        for (day, minutes) in dayMinutes {
            if minutes > options.dailyCapacityMinutes {
                overloadedDays.append(day)
            }
        }
        
        // 生成建議
        if !overloadedDays.isEmpty {
            suggestions.append("⚠️ 有 \(overloadedDays.count) 天的工作量超過每日容量，建議重新分配任務或調整截止日期。")
        }
        
        if !skippedTasks.isEmpty {
            suggestions.append("📋 有 \(skippedTasks.count) 個任務無法自動排程，請手動安排或調整條件。")
        }
        
        let highPriorityUnscheduled = skippedTasks.filter { $0.task.priority == .high }
        if !highPriorityUnscheduled.isEmpty {
            suggestions.append("🔴 有 \(highPriorityUnscheduled.count) 個高優先級任務未排程，建議優先處理。")
        }
        
        let overdueTasks = updatedTasks.filter { $0.isOverdue && !$0.isDone }
        if !overdueTasks.isEmpty {
            suggestions.append("⏰ 有 \(overdueTasks.count) 個任務已過期，請盡快處理。")
        }
        
        if scheduledCount > 0 {
            suggestions.insert("✅ 成功排程 \(scheduledCount) 個任務，共 \(formatMinutes(totalScheduledMinutes))。", at: 0)
        }
        
        return AutoPlanReport(
            scheduledTasks: scheduledTasks,
            skippedTasks: skippedTasks,
            overloadedDays: overloadedDays,
            totalScheduledMinutes: totalScheduledMinutes,
            suggestions: suggestions
        )
    }
    
    /// 格式化分鐘數為人類可讀格式
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) 分鐘"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) 小時"
            } else {
                return "\(hours) 小時 \(remainingMinutes) 分鐘"
            }
        }
    }
    
    /// 優化現有排程 - 平衡每天的負載
    func optimizeSchedule(tasks: [Task], options: AutoPlanOptions) -> [Task] {
        let calendar = Calendar.current
        var optimizedTasks = tasks
        let today = calendar.startOfDay(for: Date())
        
        // 計算每天的負載
        var dayLoad: [Date: Int] = [:]
        var dayTasks: [Date: [Task]] = [:]
        
        for task in tasks {
            guard let planned = task.plannedDate, !task.isDone, !task.isDateLocked else { continue }
            let plannedDay = calendar.startOfDay(for: planned)
            
            dayLoad[plannedDay, default: 0] += task.estimatedMinutes ?? 60
            dayTasks[plannedDay, default: []].append(task)
        }
        
        // 找出過載的日期和負載較輕的日期
        var overloadedDays = dayLoad.filter { $0.value > options.dailyCapacityMinutes }
        let underloadedDays = dayLoad.filter { $0.value < options.dailyCapacityMinutes / 2 }
        
        // 嘗試將過載日期的任務移到負載較輕的日期
        for (overloadedDay, _) in overloadedDays.sorted(by: { $0.value > $1.value }) {
            guard let tasksToMove = dayTasks[overloadedDay] else { continue }
            
            // 按優先級從低到高排序（先移動低優先級的任務）
            let sortedTasks = tasksToMove.sorted { $0.priority.hierarchyValue < $1.priority.hierarchyValue }
            
            for task in sortedTasks {
                // 跳過有截止日期限制的任務
                if let deadline = task.deadlineAt {
                    let deadlineDay = calendar.startOfDay(for: deadline)
                    if deadlineDay <= overloadedDay {
                        continue
                    }
                }
                
                // 找一個負載較輕的日期
                let targetDay = underloadedDays.keys
                    .filter { $0 >= today }
                    .filter { day in
                        if let deadline = task.deadlineAt {
                            return day <= deadline
                        }
                        return true
                    }
                    .min { dayLoad[$0, default: 0] < dayLoad[$1, default: 0] }
                
                if let targetDay = targetDay,
                   let taskIndex = optimizedTasks.firstIndex(where: { $0.id == task.id }) {
                    let taskDuration = task.estimatedMinutes ?? 60
                    let newLoad = dayLoad[targetDay, default: 0] + taskDuration
                    
                    // 確保目標日期不會因此過載
                    if newLoad <= options.dailyCapacityMinutes {
                        optimizedTasks[taskIndex].plannedDate = targetDay
                        dayLoad[overloadedDay, default: 0] -= taskDuration
                        dayLoad[targetDay, default: 0] = newLoad
                        
                        // 如果原日期不再過載，停止移動
                        if dayLoad[overloadedDay, default: 0] <= options.dailyCapacityMinutes {
                            break
                        }
                    }
                }
            }
        }
        
        return optimizedTasks
    }
}
