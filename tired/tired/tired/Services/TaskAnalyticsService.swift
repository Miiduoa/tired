import Foundation
import FirebaseFirestore

/// 任務統計分析服務
class TaskAnalyticsService {
    private let db = FirebaseManager.shared.db

    // MARK: - 基本統計

    /// 獲取任務總覽
    func getTaskOverview(userId: String) async throws -> TaskOverview {
        let now = Date()
        let calendar = Calendar.current

        // 獲取所有任務
        let allTasks = try await getAllTasks(for: userId)

        let totalTasks = allTasks.count
        let completedTasks = allTasks.filter { $0.isDone }.count
        let pendingTasks = totalTasks - completedTasks

        // 計算本週完成的任務
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let completedThisWeek = allTasks.filter {
            $0.isDone && ($0.doneAt ?? $0.createdAt) >= weekStart
        }.count

        // 計算平均完成時間
        let avgCompletionTime = calculateAverageCompletionTime(tasks: allTasks)

        // 計算準時完成率
        let onTimeCompletionRate = calculateOnTimeCompletionRate(tasks: allTasks)

        return TaskOverview(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            completedThisWeek: completedThisWeek,
            averageCompletionTime: avgCompletionTime,
            onTimeCompletionRate: onTimeCompletionRate,
            lastUpdated: now
        )
    }

    /// 按分類統計任務
    func getTasksByCategory(_ userId: String) async throws -> [CategoryStats] {
        let allTasks = try await getAllTasks(for: userId)

        var categoryCounts: [TaskCategory: (total: Int, completed: Int)] = [:]

        for task in allTasks {
            categoryCounts[task.category, default: (0, 0)].total += 1
            if task.isDone {
                categoryCounts[task.category, default: (0, 0)].completed += 1
            }
        }

        return categoryCounts.map { category, counts in
            let completionRate = counts.total > 0 ? Double(counts.completed) / Double(counts.total) : 0.0
            return CategoryStats(
                category: category,
                totalTasks: counts.total,
                completedTasks: counts.completed,
                completionRate: completionRate
            )
        }.sorted { $0.totalTasks > $1.totalTasks }
    }

    /// 按優先級統計任務
    func getTasksByPriority(_ userId: String) async throws -> [PriorityStats] {
        let allTasks = try await getAllTasks(for: userId)

        var priorityCounts: [TaskPriority: (total: Int, completed: Int)] = [:]

        for task in allTasks {
            priorityCounts[task.priority, default: (0, 0)].total += 1
            if task.isDone {
                priorityCounts[task.priority, default: (0, 0)].completed += 1
            }
        }

        return priorityCounts.map { priority, counts in
            let completionRate = counts.total > 0 ? Double(counts.completed) / Double(counts.total) : 0.0
            return PriorityStats(
                priority: priority,
                totalTasks: counts.total,
                completedTasks: counts.completed,
                completionRate: completionRate
            )
        }.sorted { $0.totalTasks > $1.totalTasks }
    }

    // MARK: - 時間序列統計

    /// 獲取每日生產力統計
    func getDailyProductivity(userId: String, days: Int = 30) async throws -> [DailyStats] {
        let allTasks = try await getAllTasks(for: userId)
        let calendar = Calendar.current
        let now = Date()

        var dailyStats: [Date: (completed: Int, totalMinutes: Int)] = [:]

        // 計算指定天數內的統計
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayTasks = allTasks.filter { task in
                if let doneAt = task.doneAt {
                    return doneAt >= dayStart && doneAt < dayEnd
                }
                return false
            }

            let totalMinutes = dayTasks.reduce(0) { sum, task in sum + (task.actualMinutes ?? task.estimatedMinutes ?? 0) }

            dailyStats[dayStart] = (completed: dayTasks.count, totalMinutes: totalMinutes)
        }

        return dailyStats.sorted { $0.key < $1.key }.map { date, stats in
            DailyStats(
                date: date,
                completedTasks: stats.completed,
                totalMinutesWorked: stats.totalMinutes
            )
        }
    }

    /// 獲取週趨勢統計
    func getWeeklyTrends(userId: String, weeks: Int = 12) async throws -> [WeeklyStats] {
        let allTasks = try await getAllTasks(for: userId)
        let calendar = Calendar.current
        let now = Date()

        var weeklyStats: [Date: (completed: Int, totalMinutes: Int, totalTasks: Int)] = [:]

        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }

            let weekTasks = allTasks.filter { task in
                let taskDate = task.doneAt ?? task.createdAt
                return taskDate >= weekInterval.start && taskDate < weekInterval.end
            }

            let completedTasks = weekTasks.filter { $0.isDone }.count
            let totalMinutes = weekTasks.reduce(0) { sum, task in sum + (task.actualMinutes ?? task.estimatedMinutes ?? 0) }

            weeklyStats[weekInterval.start] = (
                completed: completedTasks,
                totalMinutes: totalMinutes,
                totalTasks: weekTasks.count
            )
        }

        return weeklyStats.sorted { $0.key < $1.key }.map { weekStart, stats in
            let completionRate = stats.totalTasks > 0 ? Double(stats.completed) / Double(stats.totalTasks) : 0.0
            return WeeklyStats(
                weekStart: weekStart,
                completedTasks: stats.completed,
                totalTasks: stats.totalTasks,
                totalMinutesWorked: stats.totalMinutes,
                completionRate: completionRate
            )
        }
    }

    // MARK: - 生產力見解

    /// 生成生產力見解
    func generateProductivityInsights(userId: String) async throws -> [ProductivityInsight] {
        let allTasks = try await getAllTasks(for: userId)
        let now = Date()
        let calendar = Calendar.current

        var insights: [ProductivityInsight] = []

        // 1. 檢查最近的生產力趨勢
        let recentTasks = allTasks.filter { task in
            let taskDate = task.doneAt ?? task.createdAt
            return calendar.dateComponents([.day], from: taskDate, to: now).day ?? 30 <= 7
        }

        let recentCompletionRate = recentTasks.isEmpty ? 0.0 : Double(recentTasks.filter { $0.isDone }.count) / Double(recentTasks.count)

        if recentCompletionRate > 0.8 {
            insights.append(ProductivityInsight(
                type: .positive,
                title: "生產力高峰",
                description: "您最近一週的任務完成率高達 \(Int(recentCompletionRate * 100))%，保持良好的工作節奏！",
                icon: "📈",
                actionable: false,
                actionTitle: nil
            ))
        } else if recentCompletionRate < 0.5 {
            insights.append(ProductivityInsight(
                type: .warning,
                title: "需要調整節奏",
                description: "最近任務完成率偏低，建議檢查任務優先級或時間管理。",
                icon: "⚠️",
                actionable: true,
                actionTitle: "查看待辦任務"
            ))
        }

        // 2. 檢查時間估計準確性
        let completedTasksWithTime = allTasks.filter { $0.isDone && $0.estimatedMinutes != nil && $0.actualMinutes != nil }
        if !completedTasksWithTime.isEmpty {
            let avgEstimationError = completedTasksWithTime.reduce(0.0) { sum, task in
                let estimated = Double(task.estimatedMinutes!)
                let actual = Double(task.actualMinutes!)
                let error = abs(actual - estimated) / estimated
                return sum + error
            } / Double(completedTasksWithTime.count)

            if avgEstimationError > 0.3 {
                insights.append(ProductivityInsight(
                    type: .info,
                    title: "時間估計需要調整",
                    description: "您的時間估計平均誤差為 \(Int(avgEstimationError * 100))%，建議更精確地估計任務時間。",
                    icon: "⏱️",
                    actionable: true,
                    actionTitle: "優化時間估計"
                ))
            }
        }

        // 3. 檢查過期任務
        let overdueTasks = allTasks.filter { $0.isOverdue && !$0.isDone }
        if !overdueTasks.isEmpty {
            insights.append(ProductivityInsight(
                type: .urgent,
                title: "有 \(overdueTasks.count) 個任務已過期",
                description: "及時處理過期任務，避免影響整體進度。",
                icon: "🚨",
                actionable: true,
                actionTitle: "查看過期任務"
            ))
        }

        // 4. 檢查工作負載平衡
        let dailyStats = try await getDailyProductivity(userId: userId, days: 7)
        let avgDailyMinutes = dailyStats.reduce(0) { $0 + $1.totalMinutesWorked } / max(1, dailyStats.count)

        if avgDailyMinutes > 480 { // 8小時
            insights.append(ProductivityInsight(
                type: .warning,
                title: "工作負載過重",
                description: "您平均每日工作時間超過8小時，建議合理安排休息時間。",
                icon: "😰",
                actionable: true,
                actionTitle: "調整工作計劃"
            ))
        }

        return insights
    }

    // MARK: - 時間估計統計

    /// 獲取時間估計準確性統計
    func getTimeEstimationAccuracy(userId: String) async throws -> TimeEstimationStats {
        let completedTasks = try await getAllTasks(for: userId).filter { $0.isDone && $0.estimatedMinutes != nil && $0.actualMinutes != nil }

        guard !completedTasks.isEmpty else {
            return TimeEstimationStats(
                totalTasks: 0,
                averageEstimationError: 0.0,
                estimationAccuracy: 0.0,
                overestimationRate: 0.0,
                underestimationRate: 0.0
            )
        }

        var totalError = 0.0
        var accurateEstimations = 0
        var overestimations = 0
        var underestimations = 0

        for task in completedTasks {
            let estimated = Double(task.estimatedMinutes!)
            let actual = Double(task.actualMinutes!)
            let error = abs(actual - estimated) / estimated

            totalError += error

            if error <= 0.1 { // 10%以內算準確
                accurateEstimations += 1
            } else if actual > estimated {
                underestimations += 1
            } else {
                overestimations += 1
            }
        }

        let avgError = totalError / Double(completedTasks.count)
        let accuracy = Double(accurateEstimations) / Double(completedTasks.count)

        return TimeEstimationStats(
            totalTasks: completedTasks.count,
            averageEstimationError: avgError,
            estimationAccuracy: accuracy,
            overestimationRate: Double(overestimations) / Double(completedTasks.count),
            underestimationRate: Double(underestimations) / Double(completedTasks.count)
        )
    }

    // MARK: - 最有效時間段

    /// 獲取最有效率的時間段統計
    func getMostProductiveHours(userId: String) async throws -> [HourlyStats] {
        let allTasks = try await getAllTasks(for: userId).filter { $0.isDone && $0.doneAt != nil }

        var hourlyStats: [Int: (count: Int, totalMinutes: Int)] = [:]

        let calendar = Calendar.current

        for task in allTasks {
            guard let doneAt = task.doneAt else { continue }

            let hour = calendar.component(.hour, from: doneAt)
            let minutes = task.actualMinutes ?? task.estimatedMinutes ?? 0

            hourlyStats[hour, default: (0, 0)].count += 1
            hourlyStats[hour, default: (0, 0)].totalMinutes += minutes
        }

        return hourlyStats.map { hour, stats in
            let avgMinutes = stats.count > 0 ? stats.totalMinutes / stats.count : 0
            return HourlyStats(
                hour: hour,
                completedTasks: stats.count,
                averageMinutesPerTask: avgMinutes
            )
        }.sorted { $0.completedTasks > $1.completedTasks }
    }

    // MARK: - 輔助方法

    /// 獲取用戶的所有任務
    private func getAllTasks(for userId: String) async throws -> [Task] {
        let snapshot = try await db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Task? in
            try? doc.data(as: Task.self)
        }
    }

    /// 計算平均完成時間（小時）
    private func calculateAverageCompletionTime(tasks: [Task]) -> Double {
        let completedTasks = tasks.filter { $0.isDone && $0.doneAt != nil }

        guard !completedTasks.isEmpty else { return 0.0 }

        let totalHours = completedTasks.reduce(0.0) { sum, task in
            guard let doneAt = task.doneAt else { return sum }
            let interval = doneAt.timeIntervalSince(task.createdAt)
            return sum + (interval / 3600.0) // 轉換為小時
        }

        return totalHours / Double(completedTasks.count)
    }

    /// 計算準時完成率
    private func calculateOnTimeCompletionRate(tasks: [Task]) -> Double {
        let tasksWithDeadline = tasks.filter { $0.isDone && $0.deadlineAt != nil }

        guard !tasksWithDeadline.isEmpty else { return 0.0 }

        let onTimeTasks = tasksWithDeadline.filter { task in
            guard let deadline = task.deadlineAt, let doneAt = task.doneAt else { return false }
            return doneAt <= deadline
        }

        return Double(onTimeTasks.count) / Double(tasksWithDeadline.count)
    }
}

// MARK: - 統計數據結構

struct TaskOverview {
    let totalTasks: Int
    let completedTasks: Int
    let pendingTasks: Int
    let completedThisWeek: Int
    let averageCompletionTime: Double // 小時
    let onTimeCompletionRate: Double  // 0.0 - 1.0
    let lastUpdated: Date
}

struct CategoryStats {
    let category: TaskCategory
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double // 0.0 - 1.0
}

struct PriorityStats {
    let priority: TaskPriority
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double // 0.0 - 1.0
}

struct DailyStats {
    let date: Date
    let completedTasks: Int
    let totalMinutesWorked: Int
}

struct WeeklyStats {
    let weekStart: Date
    let completedTasks: Int
    let totalTasks: Int
    let totalMinutesWorked: Int
    let completionRate: Double // 0.0 - 1.0
}

struct ProductivityInsight {
    enum InsightType {
        case positive, warning, urgent, info
    }

    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let actionable: Bool
    let actionTitle: String?
}

struct TimeEstimationStats {
    let totalTasks: Int
    let averageEstimationError: Double // 0.0 - 1.0 (誤差百分比)
    let estimationAccuracy: Double     // 0.0 - 1.0 (準確估計的比例)
    let overestimationRate: Double     // 0.0 - 1.0
    let underestimationRate: Double    // 0.0 - 1.0
}

struct HourlyStats {
    let hour: Int // 0-23
    let completedTasks: Int
    let averageMinutesPerTask: Int
}