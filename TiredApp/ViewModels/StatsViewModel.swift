import Foundation
import Combine
import FirebaseAuth

/// 統計數據 ViewModel
class StatsViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats?
    @Published var categoryStats: [CategoryStat] = []
    @Published var isLoading = false

    private let taskService = TaskService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        loadStats()
    }

    func loadStats() {
        guard let userId = userId else { return }

        isLoading = true

        // 獲取所有任務（包括已完成和未完成）
        Task {
            do {
                let allTasks = try await fetchAllTasks(userId: userId)
                await calculateStats(from: allTasks)

                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("❌ Error loading stats: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func fetchAllTasks(userId: String) async throws -> [Task] {
        let snapshot = try await FirebaseManager.shared.db
            .collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Task? in
            try? doc.data(as: Task.self)
        }
    }

    private func calculateStats(from tasks: [Task]) async {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        // 本週任務
        let weekTasks = tasks.filter { task in
            if let createdAt = task.createdAt as Date?,
               createdAt >= weekStart && createdAt < weekEnd {
                return true
            }
            if let planned = task.plannedDate,
               planned >= weekStart && planned < weekEnd {
                return true
            }
            return false
        }

        let completedWeekTasks = weekTasks.filter { $0.isDone }
        let pendingWeekTasks = weekTasks.filter { !$0.isDone }

        // 計算總預估時長
        let totalEstimatedMinutes = pendingWeekTasks.compactMap { $0.estimatedMinutes }.reduce(0, +)

        // 本週統計
        let weeklyStats = WeeklyStats(
            completedCount: completedWeekTasks.count,
            pendingCount: pendingWeekTasks.count,
            totalEstimatedHours: Double(totalEstimatedMinutes) / 60.0,
            completionRate: weekTasks.isEmpty ? 0 : Double(completedWeekTasks.count) / Double(weekTasks.count) * 100
        )

        // 分類統計
        var categoryDict: [TaskCategory: CategoryStat] = [:]

        for task in tasks.filter({ !$0.isDone }) {
            let category = task.category
            if var stat = categoryDict[category] {
                stat.count += 1
                if let minutes = task.estimatedMinutes {
                    stat.totalMinutes += minutes
                }
                categoryDict[category] = stat
            } else {
                categoryDict[category] = CategoryStat(
                    category: category,
                    count: 1,
                    totalMinutes: task.estimatedMinutes ?? 0
                )
            }
        }

        let categoryStats = Array(categoryDict.values).sorted { $0.count > $1.count }

        await MainActor.run {
            self.weeklyStats = weeklyStats
            self.categoryStats = categoryStats
        }
    }
}

// MARK: - Data Models

struct WeeklyStats {
    let completedCount: Int
    let pendingCount: Int
    let totalEstimatedHours: Double
    let completionRate: Double
}

struct CategoryStat {
    let category: TaskCategory
    var count: Int
    var totalMinutes: Int

    var totalHours: Double {
        Double(totalMinutes) / 60.0
    }
}
