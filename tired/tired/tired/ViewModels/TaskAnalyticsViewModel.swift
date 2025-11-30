import Foundation
import Combine

/// 任務統計分析視圖模型
class TaskAnalyticsViewModel: ObservableObject {
    @Published var taskOverview: TaskOverview?
    @Published var categoryStats: [CategoryStats] = []
    @Published var priorityStats: [PriorityStats] = []
    @Published var dailyStats: [DailyStats] = []
    @Published var weeklyTrends: [WeeklyStats] = []
    @Published var productivityInsights: [ProductivityInsight] = []
    @Published var timeEstimationStats: TimeEstimationStats?
    @Published var mostProductiveHours: [HourlyStats] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let analyticsService: TaskAnalyticsService
    private var cancellables = Set<AnyCancellable>()
    private var userId: String?

    init(analyticsService: TaskAnalyticsService = TaskAnalyticsService()) {
        self.analyticsService = analyticsService
    }

    func setUserId(_ userId: String) {
        self.userId = userId
        loadAllAnalytics()
    }

    /// 載入所有統計數據
    func loadAllAnalytics() {
        guard let userId = userId else { return }

        isLoading = true
        errorMessage = nil

        // 使用 TaskGroup 並發載入所有數據
        _Concurrency.Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadTaskOverview(userId: userId) }
                group.addTask { await self.loadCategoryStats(userId: userId) }
                group.addTask { await self.loadPriorityStats(userId: userId) }
                group.addTask { await self.loadDailyStats(userId: userId) }
                group.addTask { await self.loadWeeklyTrends(userId: userId) }
                group.addTask { await self.loadProductivityInsights(userId: userId) }
                group.addTask { await self.loadTimeEstimationStats(userId: userId) }
                group.addTask { await self.loadMostProductiveHours(userId: userId) }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    /// 載入任務概覽
    private func loadTaskOverview(userId: String) async {
        do {
            let overview = try await analyticsService.getTaskOverview(userId: userId)
            await MainActor.run {
                self.taskOverview = overview
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入任務概覽失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入分類統計
    private func loadCategoryStats(userId: String) async {
        do {
            let stats = try await analyticsService.getTasksByCategory(userId)
            await MainActor.run {
                self.categoryStats = stats
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入分類統計失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入優先級統計
    private func loadPriorityStats(userId: String) async {
        do {
            let stats = try await analyticsService.getTasksByPriority(userId)
            await MainActor.run {
                self.priorityStats = stats
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入優先級統計失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入每日統計
    private func loadDailyStats(userId: String) async {
        do {
            let stats = try await analyticsService.getDailyProductivity(userId: userId, days: 30)
            await MainActor.run {
                self.dailyStats = stats
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入每日統計失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入週趨勢
    private func loadWeeklyTrends(userId: String) async {
        do {
            let trends = try await analyticsService.getWeeklyTrends(userId: userId, weeks: 12)
            await MainActor.run {
                self.weeklyTrends = trends
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入週趨勢失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入生產力見解
    private func loadProductivityInsights(userId: String) async {
        do {
            let insights = try await analyticsService.generateProductivityInsights(userId: userId)
            await MainActor.run {
                self.productivityInsights = insights
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入生產力見解失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入時間估計統計
    private func loadTimeEstimationStats(userId: String) async {
        do {
            let stats = try await analyticsService.getTimeEstimationAccuracy(userId: userId)
            await MainActor.run {
                self.timeEstimationStats = stats
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入時間估計統計失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 載入最有效時間段
    private func loadMostProductiveHours(userId: String) async {
        do {
            let hours = try await analyticsService.getMostProductiveHours(userId: userId)
            await MainActor.run {
                self.mostProductiveHours = hours
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "載入最有效時間段失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 刷新數據
    func refresh() {
        loadAllAnalytics()
    }

    /// 獲取特定時間範圍的統計
    func getStatsForDateRange(startDate: Date, endDate: Date) async throws -> [DailyStats] {
        guard let userId = userId else { throw NSError(domain: "TaskAnalytics", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"]) }

        return try await analyticsService.getDailyProductivity(userId: userId, days: 30)
            .filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// 獲取分類完成率趨勢
    func getCategoryCompletionTrends(userId: String, category: TaskCategory, days: Int = 30) async throws -> [CategoryDailyStats] {
        _ = try await analyticsService.getTasksByCategory(userId).first(where: { $0.category == category })

        // 這裡可以實現更複雜的分類每日趨勢邏輯
        // 目前先返回空數組
        return []
    }
}

// MARK: - 擴展統計結構

struct CategoryDailyStats {
    let date: Date
    let completedTasks: Int
    let totalTasks: Int
    let completionRate: Double
}