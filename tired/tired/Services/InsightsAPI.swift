import Foundation

enum InsightsAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case invalidDateRange
}

// MARK: - Supporting Types

extension InsightsAPI {
    static func getDashboardSummary(tenantId: String) async throws -> DashboardSummary {
        // Mock data
        return DashboardSummary(
            totalMembers: 150,
            activeRate: 0.85,
            weeklyEvents: 12,
            avgAttendanceRate: 0.92
        )
    }
    
    static func getAttendanceAnalytics(tenantId: String, period: String) async throws -> AttendanceAnalyticsData {
        // Mock data
        let calendar = Calendar.current
        let today = Date()
        var dailyRates: [DailyAttendanceRate] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dailyRates.append(DailyAttendanceRate(
                    date: date,
                    rate: Double.random(in: 0.75...0.95)
                ))
            }
        }
        
        return AttendanceAnalyticsData(
            avgRate: 0.87,
            maxRate: 0.95,
            minRate: 0.75,
            dailyRates: dailyRates.reversed()
        )
    }
    
    static func getActivityEngagement(tenantId: String, period: String) async throws -> ActivityEngagement {
        // Mock data
        return ActivityEngagement(
            typeDistribution: [
                ActivityTypeCount(type: "活動", count: 25),
                ActivityTypeCount(type: "投票", count: 18),
                ActivityTypeCount(type: "公告", count: 42)
            ],
            topParticipants: [
                ParticipantActivity(userId: "1", userName: "張小明", count: 45),
                ParticipantActivity(userId: "2", userName: "李小華", count: 38),
                ParticipantActivity(userId: "3", userName: "王小美", count: 32),
                ParticipantActivity(userId: "4", userName: "陳小強", count: 28),
                ParticipantActivity(userId: "5", userName: "林小芳", count: 24)
            ]
        )
    }
    
    static func getMemberActivity(tenantId: String, topN: Int) async throws -> [MemberActivity] {
        // Mock data
        return (1...topN).map { i in
            MemberActivity(
                id: "\(i)",
                userId: "user\(i)",
                userName: "用戶 \(i)",
                activityCount: Int.random(in: 10...50),
                lastActive: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )
        }
    }
    
    static func exportReport(tenantId: String, reportType: String, format: String) async throws -> URL {
        // Mock URL
        return URL(string: "https://example.com/reports/\(tenantId)-\(reportType).\(format)")!
    }
}

/// 數據分析與洞察 API 服務
struct InsightsAPI {
    
    // MARK: - 獲取儀表板數據
    
    /// 獲取組織儀表板數據
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - period: 統計期間
    /// - Returns: 洞察區塊列表
    static func fetchDashboard(
        groupId: String,
        period: DateInterval? = nil
    ) async throws -> [InsightSection] {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            // 離線模式：返回模擬數據
            return InsightSection.mockData()
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/insights/dashboard")!
        var queryItems = [URLQueryItem(name: "groupId", value: groupId)]
        
        if let period = period {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: period.start)))
            queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: period.end)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw InsightsAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InsightsAPIError.requestFailed("Failed to fetch dashboard")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([InsightSection].self, from: data)
    }
    
    // MARK: - 出勤分析
    
    /// 獲取出勤統計分析
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    /// - Returns: 出勤分析數據
    static func fetchAttendanceAnalytics(
        groupId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> AttendanceAnalyticsData {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            // 離線模式
            return AttendanceAnalyticsData.mock()
        }
        
        let formatter = ISO8601DateFormatter()
        var components = URLComponents(string: "\(endpoint)/v1/insights/attendance")!
        components.queryItems = [
            URLQueryItem(name: "groupId", value: groupId),
            URLQueryItem(name: "start", value: formatter.string(from: startDate)),
            URLQueryItem(name: "end", value: formatter.string(from: endDate))
        ]
        
        guard let url = components.url else {
            throw InsightsAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InsightsAPIError.requestFailed("Failed to fetch attendance analytics")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AttendanceAnalyticsData.self, from: data)
    }
    
    // MARK: - 活動參與分析
    
    /// 獲取活動參與統計
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - eventIds: 活動 ID 列表（可選）
    /// - Returns: 活動分析數據
    static func fetchActivityAnalytics(
        groupId: String,
        eventIds: [String]? = nil
    ) async throws -> ActivityAnalytics {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            return ActivityAnalytics.mock()
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/insights/activities")!
        var queryItems = [URLQueryItem(name: "groupId", value: groupId)]
        
        if let eventIds = eventIds {
            queryItems.append(URLQueryItem(name: "eventIds", value: eventIds.joined(separator: ",")))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw InsightsAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InsightsAPIError.requestFailed("Failed to fetch activity analytics")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ActivityAnalytics.self, from: data)
    }
    
    // MARK: - 成員活躍度分析
    
    /// 獲取成員活躍度排行
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - limit: 返回數量限制
    /// - Returns: 活躍度排行列表
    static func fetchMemberEngagement(
        groupId: String,
        limit: Int = 20
    ) async throws -> [MemberEngagement] {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            return MemberEngagement.mockData()
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/insights/member-engagement")!
        components.queryItems = [
            URLQueryItem(name: "groupId", value: groupId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw InsightsAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InsightsAPIError.requestFailed("Failed to fetch member engagement")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([MemberEngagement].self, from: data)
    }
    
    // MARK: - 導出報表
    
    /// 導出完整報表
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - reportType: 報表類型
    ///   - period: 統計期間
    ///   - format: 文件格式
    /// - Returns: 報表下載 URL
    static func exportReport(
        groupId: String,
        reportType: ReportType,
        period: DateInterval,
        format: ExportFormat = .pdf
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/insights/export")
        else {
            return "https://example.com/reports/mock-report.\(format.rawValue)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "groupId": groupId,
            "reportType": reportType.rawValue,
            "startDate": formatter.string(from: period.start),
            "endDate": formatter.string(from: period.end),
            "format": format.rawValue
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InsightsAPIError.requestFailed("Failed to export report")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let downloadUrl = obj["downloadUrl"] as? String {
            return downloadUrl
        }
        
        throw InsightsAPIError.requestFailed("Invalid response format")
    }
}

// MARK: - 數據結構

enum ReportType: String, Codable {
    case attendance = "attendance"
    case activity = "activity"
    case engagement = "engagement"
    case esg = "esg"
    case comprehensive = "comprehensive"
}

enum ExportFormat: String, Codable {
    case pdf
    case excel
    case csv
}

// NOTE: Removed duplicate AttendanceAnalytics definition here to avoid redeclaration.
// The canonical AttendanceAnalyticsData is defined in InsightsModels.swift.

struct ActivityAnalytics: Codable {
    let totalEvents: Int
    let totalParticipants: Int
    let averageParticipationRate: Double
    let popularEvents: [PopularEvent]
    
    struct PopularEvent: Codable {
        let id: String
        let title: String
        let participants: Int
    }
    
    static func mock() -> ActivityAnalytics {
        return ActivityAnalytics(
            totalEvents: 12,
            totalParticipants: 856,
            averageParticipationRate: 0.68,
            popularEvents: [
                PopularEvent(id: "1", title: "校慶運動會", participants: 320),
                PopularEvent(id: "2", title: "學術講座", participants: 185),
                PopularEvent(id: "3", title: "社團博覽會", participants: 267)
            ]
        )
    }
}

struct MemberEngagement: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let score: Int
    let attendanceRate: Double
    let activityCount: Int
    let postCount: Int
    
    static func mockData() -> [MemberEngagement] {
        return [
            MemberEngagement(id: "1", userId: "u1", userName: "張三", score: 950, attendanceRate: 0.98, activityCount: 15, postCount: 23),
            MemberEngagement(id: "2", userId: "u2", userName: "李四", score: 890, attendanceRate: 0.95, activityCount: 12, postCount: 18),
            MemberEngagement(id: "3", userId: "u3", userName: "王五", score: 850, attendanceRate: 0.92, activityCount: 10, postCount: 20)
        ]
    }
}

// MARK: - InsightSection Mock

extension InsightSection {
    static func mockData() -> [InsightSection] {
        return [
            InsightSection(
                id: "attendance",
                title: "本月出勤統計",
                entries: [
                    InsightEntry(id: "avg-attendance", category: "attendance", title: "平均出席率", value: "92%", trend: "↑"),
                    InsightEntry(id: "late-count", category: "attendance", title: "遲到次數", value: "8", trend: "↓"),
                    InsightEntry(id: "leave-count", category: "attendance", title: "請假人次", value: "15", trend: "—")
                ]
            ),
            InsightSection(
                id: "activity",
                title: "活動參與",
                entries: [
                    InsightEntry(id: "events-this-month", category: "activity", title: "本月活動", value: "5", trend: "↑"),
                    InsightEntry(id: "total-participants", category: "activity", title: "總參與人次", value: "234", trend: "↑"),
                    InsightEntry(id: "participation-rate", category: "activity", title: "參與率", value: "78%", trend: "—")
                ]
            )
        ]
    }
}

