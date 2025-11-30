import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Tasks Stats ViewModel

class TasksStatsViewModel: ObservableObject {
    @Published var completedCount = 0
    @Published var pendingCount = 0
    @Published var totalEstimatedMinutes = 0
    @Published var totalActualMinutes = 0
    @Published var schoolCount = 0
    @Published var workCount = 0
    @Published var clubCount = 0
    @Published var personalCount = 0
    @Published var categoryData: [(category: TaskCategory, count: Int)] = []
    @Published var weeklyStats: [(day: String, count: Int)] = []

    private var cancellables = Set<AnyCancellable>()
    private let db = FirebaseManager.shared.db
    private var allTasks: [Task] = []
    private var currentTimeRange: String = "本週"
    
    var completionRate: Int {
        let total = completedCount + pendingCount
        guard total > 0 else { return 0 }
        return Int(Double(completedCount) / Double(total) * 100)
    }

    var formattedEstimatedTime: String {
        formatMinutes(totalEstimatedMinutes)
    }
    
    var formattedActualTime: String {
        formatMinutes(totalActualMinutes)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)時\(mins)分"
        } else if hours > 0 {
            return "\(hours)小時"
        } else if mins > 0 {
            return "\(mins)分鐘"
        } else {
            return "0分鐘"
        }
    }

    init() {
        loadStats()
    }
    
    func updateTimeRange(_ range: String) {
        currentTimeRange = range
        calculateStats()
    }

    private func loadStats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Listen to user's tasks
        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                self.allTasks = documents.compactMap { try? $0.data(as: Task.self) }
                self.calculateStats()
            }
    }
    
    private func calculateStats() {
        let calendar = Calendar.current
        let now = Date()
        
        // 根據時間範圍過濾任務
        let filteredTasks: [Task]
        
        switch currentTimeRange {
        case "本週":
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            filteredTasks = allTasks.filter { task in
                if let plannedDate = task.plannedDate {
                    return plannedDate >= startOfWeek
                }
                if let deadline = task.deadlineAt {
                    return deadline >= startOfWeek
                }
                if let doneAt = task.doneAt {
                    return doneAt >= startOfWeek
                }
                return !task.isDone
            }
        case "本月":
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            filteredTasks = allTasks.filter { task in
                if let plannedDate = task.plannedDate {
                    return plannedDate >= startOfMonth
                }
                if let deadline = task.deadlineAt {
                    return deadline >= startOfMonth
                }
                if let doneAt = task.doneAt {
                    return doneAt >= startOfMonth
                }
                return !task.isDone
            }
        default: // "全部"
            filteredTasks = allTasks
        }

        // 計算基本統計
        completedCount = filteredTasks.filter { $0.isDone }.count
        pendingCount = filteredTasks.filter { !$0.isDone }.count
        totalEstimatedMinutes = filteredTasks.compactMap { $0.estimatedMinutes }.reduce(0, +)
        totalActualMinutes = filteredTasks.compactMap { $0.actualMinutes }.reduce(0, +)
        
        // 計算分類統計
        schoolCount = filteredTasks.filter { $0.category == .school }.count
        workCount = filteredTasks.filter { $0.category == .work }.count
        clubCount = filteredTasks.filter { $0.category == .club }.count
        personalCount = filteredTasks.filter { $0.category == .personal }.count
        
        // 生成分類數據（用於圖表）
        categoryData = [
            (category: .school, count: schoolCount),
            (category: .work, count: workCount),
            (category: .club, count: clubCount),
            (category: .personal, count: personalCount)
        ].sorted { $0.count > $1.count }
        
        // 生成本週每日統計
        calculateWeeklyStats(from: filteredTasks)
    }
    
    private func calculateWeeklyStats(from tasks: [Task]) {
        let calendar = Calendar.current
        let now = Date()
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        
        // 獲取本週的開始日期
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            weeklyStats = weekdays.map { ($0, 0) }
            return
        }
        
        var stats: [(day: String, count: Int)] = []
        
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                stats.append((weekdays[dayOffset], 0))
                continue
            }
            
            let startOfDay = calendar.startOfDay(for: dayDate)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                stats.append((weekdays[dayOffset], 0))
                continue
            }
            
            // 計算這一天完成的任務數量
            let dayTasks = tasks.filter { task in
                if let doneAt = task.doneAt {
                    return doneAt >= startOfDay && doneAt < endOfDay
                }
                if let plannedDate = task.plannedDate {
                    return plannedDate >= startOfDay && plannedDate < endOfDay
                }
                return false
            }
            
            let weekdayIndex = calendar.component(.weekday, from: dayDate) - 1 // 0-6
            stats.append((weekdays[weekdayIndex], dayTasks.count))
        }
        
        weeklyStats = stats
    }
}
