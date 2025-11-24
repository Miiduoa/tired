import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Time Block Types

/// 时间块类型（性质）
enum TimeBlockType: String, Codable {
    case hard      // 硬阻止：任何任务都不能排进去
    case soft      // 软限制：尽量不排，但容量满时可以排
    case flexible  // 灵活：可以部分使用

    var displayName: String {
        switch self {
        case .hard: return "硬阻止"
        case .soft: return "软限制"
        case .flexible: return "灵活"
        }
    }

    var description: String {
        switch self {
        case .hard: return "任何任务都不能排进这个时间段"
        case .soft: return "尽量避免排程任务，但容量充足时可以使用"
        case .flexible: return "可以灵活调整的时间段"
        }
    }
}

/// 时间段（用于表示每天的某个时间段）
struct TimeOfDay: Codable, Equatable, Comparable {
    let hour: Int    // 0-23
    let minute: Int  // 0-59

    var displayName: String {
        let hourStr = String(format: "%02d", hour)
        let minStr = String(format: "%02d", minute)
        return "\(hourStr):\(minStr)"
    }

    var totalMinutes: Int {
        hour * 60 + minute
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    static func now() -> TimeOfDay {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return TimeOfDay(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }
}

// MARK: - Time Block Model

/// 时间块（预留/保护特定时间段）
struct TimeBlock: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String

    let title: String           // "午餐", "运动", "深度工作"
    let color: String?          // 十六进制颜色
    let icon: String?           // SF Symbol 图标

    // 时间段信息
    let startTime: TimeOfDay
    let endTime: TimeOfDay

    /// 重复规则
    enum RepeatRule: String, Codable {
        case none          // 一次性
        case daily         // 每天
        case weekdays      // 工作日
        case weekends      // 周末
        case weekly        // 每周特定日期
    }

    let repeatRule: RepeatRule
    let dayOfWeek: Int?  // 1-7: Monday-Sunday (仅用于 weekly)

    let blockType: TimeBlockType

    /// 应用范围
    let startDate: Date?     // 开始日期
    let endDate: Date?       // 结束日期（nil = 永久）

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, title, color, icon
        case startTime, endTime
        case repeatRule, dayOfWeek
        case blockType
        case startDate, endDate
        case createdAt, updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        title: String,
        color: String? = nil,
        icon: String? = nil,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        repeatRule: RepeatRule = .none,
        dayOfWeek: Int? = nil,
        blockType: TimeBlockType,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.color = color
        self.icon = icon
        self.startTime = startTime
        self.endTime = endTime
        self.repeatRule = repeatRule
        self.dayOfWeek = dayOfWeek
        self.blockType = blockType
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 检查特定日期是否有这个时间块
    func isActiveOn(_ date: Date) -> Bool {
        let calendar = Calendar.current

        // 检查日期范围
        if let start = startDate, date < calendar.startOfDay(for: start) {
            return false
        }
        if let end = endDate, date > end {
            return false
        }

        // 检查重复规则
        switch repeatRule {
        case .none:
            // 一次性：只在 startDate（如果有）有效
            if let startDate = startDate {
                return calendar.isDate(date, inSameDayAs: startDate)
            }
            return false

        case .daily:
            return true

        case .weekdays:
            let dayOfWeek = calendar.component(.weekday, from: date)
            return (2...6).contains(dayOfWeek)  // 周一到周五

        case .weekends:
            let dayOfWeek = calendar.component(.weekday, from: date)
            return dayOfWeek == 1 || dayOfWeek == 7

        case .weekly:
            let dayOfWeek = calendar.component(.weekday, from: date)
            // 转换为我们的格式（1=周一，7=周日）
            let normalizedDayOfWeek = dayOfWeek == 1 ? 7 : dayOfWeek - 1
            return normalizedDayOfWeek == (dayOfWeek ?? 1)
        }
    }

    /// 获取持续时间（分钟）
    var durationMinutes: Int {
        let start = startTime.totalMinutes
        let end = endTime.totalMinutes

        if end > start {
            return end - start
        } else {
            // 跨越午夜
            return (24 * 60 - start) + end
        }
    }
}

// MARK: - Helper Models

/// 时间段（用于可用时间计算）
struct TimeSlot: Codable {
    let startTime: TimeOfDay
    let endTime: TimeOfDay

    init(start: TimeOfDay, end: TimeOfDay) {
        self.startTime = start
        self.endTime = end
    }

    /// 初始化字符串格式的时间段（如 "09:00" 到 "17:00"）
    init?(startStr: String, endStr: String) {
        let startParts = startStr.split(separator: ":").compactMap { Int($0) }
        let endParts = endStr.split(separator: ":").compactMap { Int($0) }

        guard startParts.count == 2, endParts.count == 2 else { return nil }

        self.startTime = TimeOfDay(hour: startParts[0], minute: startParts[1])
        self.endTime = TimeOfDay(hour: endParts[0], minute: endParts[1])
    }

    /// 检查是否与时间块重叠
    func overlaps(with timeBlock: TimeBlock) -> Bool {
        return !(endTime <= timeBlock.startTime || startTime >= timeBlock.endTime)
    }

    /// 从此时间段中减去一个时间块，返回剩余的时间段
    func subtracting(_ timeBlock: TimeBlock) -> [TimeSlot] {
        var result: [TimeSlot] = []

        if endTime <= timeBlock.startTime || startTime >= timeBlock.endTime {
            // 不重叠，返回原始时间段
            return [self]
        }

        // 如果时间块在时间段前面
        if timeBlock.startTime > startTime {
            result.append(TimeSlot(start: startTime, end: timeBlock.startTime))
        }

        // 如果时间块在时间段后面
        if timeBlock.endTime < endTime {
            result.append(TimeSlot(start: timeBlock.endTime, end: endTime))
        }

        return result
    }
}
