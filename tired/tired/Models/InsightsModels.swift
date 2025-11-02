import Foundation

// MARK: - Dashboard Summary

struct DashboardSummary: Codable {
    let totalMembers: Int
    let activeRate: Double
    let weeklyEvents: Int
    let avgAttendanceRate: Double
}

// MARK: - Attendance Analytics

struct AttendanceAnalyticsData: Codable {
    let avgRate: Double
    let maxRate: Double
    let minRate: Double
    let dailyRates: [DailyAttendanceRate]
    
    // Mock data consistent with this model shape
    static func mock() -> AttendanceAnalyticsData {
        let calendar = Calendar.current
        let today = Date()
        let rates: [Double] = [0.89, 0.93, 0.91, 0.95, 0.92, 0.88, 0.90]
        
        var daily: [DailyAttendanceRate] = []
        for i in 0..<rates.count {
            if let date = calendar.date(byAdding: .day, value: -(rates.count - 1 - i), to: today) {
                daily.append(DailyAttendanceRate(date: date, rate: rates[i]))
            }
        }
        
        let maxRate = daily.map { $0.rate }.max() ?? 0
        let minRate = daily.map { $0.rate }.min() ?? 0
        let avgRate = daily.map { $0.rate }.reduce(0, +) / Double(daily.count)
        
        return AttendanceAnalyticsData(
            avgRate: avgRate,
            maxRate: maxRate,
            minRate: minRate,
            dailyRates: daily
        )
    }
}

struct DailyAttendanceRate: Codable, Identifiable {
    let id: String
    let date: Date
    let rate: Double
    
    init(id: String = UUID().uuidString, date: Date, rate: Double) {
        self.id = id
        self.date = date
        self.rate = rate
    }
}

// MARK: - Activity Engagement

struct ActivityEngagement: Codable {
    let typeDistribution: [ActivityTypeCount]
    let topParticipants: [ParticipantActivity]
}

struct ActivityTypeCount: Codable, Identifiable {
    let id: String
    let type: String
    let count: Int
    
    init(id: String = UUID().uuidString, type: String, count: Int) {
        self.id = id
        self.type = type
        self.count = count
    }
}

struct ParticipantActivity: Codable {
    let userId: String
    let userName: String
    let count: Int
}

// MARK: - Member Activity

struct MemberActivity: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let activityCount: Int
    let lastActive: Date
}

