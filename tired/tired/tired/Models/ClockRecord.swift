import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Clock In/Out (打卡記錄)

/// 打卡記錄模型 - Moodle 風格的時間追蹤
struct ClockRecord: Codable, Identifiable {
    @DocumentID var id: String?

    var userId: String
    var taskId: String?              // 關聯的任務 ID（可選）
    var organizationId: String?      // 關聯的組織 ID（可選）

    // 打卡時間
    var clockInTime: Date
    var clockOutTime: Date?

    // 工作資訊
    var workDescription: String?     // 工作描述
    var location: String?            // 工作地點
    var category: String?            // 工作分類

    // 計算屬性
    var duration: TimeInterval? {
        guard let clockOut = clockOutTime else { return nil }
        return clockOut.timeIntervalSince(clockInTime)
    }

    var isActive: Bool {
        return clockOutTime == nil
    }

    // 時間戳
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case taskId
        case organizationId
        case clockInTime
        case clockOutTime
        case workDescription
        case location
        case category
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        taskId: String? = nil,
        organizationId: String? = nil,
        clockInTime: Date = Date(),
        clockOutTime: Date? = nil,
        workDescription: String? = nil,
        location: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.organizationId = organizationId
        self.clockInTime = clockInTime
        self.clockOutTime = clockOutTime
        self.workDescription = workDescription
        self.location = location
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Extensions

extension ClockRecord {
    /// 格式化工作時長
    var formattedDuration: String {
        guard let duration = duration else { return "進行中" }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours) 小時 \(minutes) 分鐘"
        } else {
            return "\(minutes) 分鐘"
        }
    }

    /// 工作時長（小時）
    var durationInHours: Double {
        guard let duration = duration else { return 0 }
        return duration / 3600.0
    }
}

// MARK: - Work Statistics (工時統計)

struct WorkStatistics {
    var totalHours: Double
    var totalRecords: Int
    var averageHoursPerDay: Double
    var recordsByCategory: [String: Double]  // 分類 -> 總時數
    var recordsByDate: [Date: Double]        // 日期 -> 總時數

    init(
        totalHours: Double = 0,
        totalRecords: Int = 0,
        averageHoursPerDay: Double = 0,
        recordsByCategory: [String: Double] = [:],
        recordsByDate: [Date: Double] = [:]
    ) {
        self.totalHours = totalHours
        self.totalRecords = totalRecords
        self.averageHoursPerDay = averageHoursPerDay
        self.recordsByCategory = recordsByCategory
        self.recordsByDate = recordsByDate
    }
}
