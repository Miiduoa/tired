import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Recurrence Rule

/// 任务重复规则
enum RecurrenceRule: Codable, Equatable {
    case daily                          // 每天
    case weekdays                       // 周一-周五
    case weekends                       // 周六-周日
    case weekly(dayOfWeek: Int)        // 每周特定某一天 (1=周一, 7=周日)
    case biweekly(dayOfWeek: Int)      // 每两周特定某一天
    case monthly(dayOfMonth: Int)      // 每月特定某一号
    case custom(daysOfWeek: [Int])     // 自定义周期 (如 [1,3,5] = 周一三五)

    var displayName: String {
        switch self {
        case .daily:
            return "每天"
        case .weekdays:
            return "工作日 (周一-周五)"
        case .weekends:
            return "周末 (周六-周日)"
        case .weekly(let day):
            return "每周\(dayName(day))"
        case .biweekly(let day):
            return "每两周\(dayName(day))"
        case .monthly(let dayOfMonth):
            return "每月 \(dayOfMonth) 号"
        case .custom(let days):
            let dayNames = days.sorted().map { dayName($0) }.joined(separator: "、")
            return "自定义: \(dayNames)"
        }
    }

    private static func dayName(_ dayOfWeek: Int) -> String {
        let names = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return (1...7).contains(dayOfWeek) ? names[dayOfWeek] : ""
    }

    // 编码/解码支持
    enum CodingKeys: String, CodingKey {
        case daily, weekdays, weekends, weekly, biweekly, monthly, custom
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(true, forKey: .daily)
        case .weekdays:
            try container.encode(true, forKey: .weekdays)
        case .weekends:
            try container.encode(true, forKey: .weekends)
        case .weekly(let dayOfWeek):
            try container.encode(dayOfWeek, forKey: .weekly)
        case .biweekly(let dayOfWeek):
            try container.encode(dayOfWeek, forKey: .biweekly)
        case .monthly(let dayOfMonth):
            try container.encode(dayOfMonth, forKey: .monthly)
        case .custom(let daysOfWeek):
            try container.encode(daysOfWeek, forKey: .custom)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if (try? container.decode(Bool.self, forKey: .daily)) != nil {
            self = .daily
        } else if (try? container.decode(Bool.self, forKey: .weekdays)) != nil {
            self = .weekdays
        } else if (try? container.decode(Bool.self, forKey: .weekends)) != nil {
            self = .weekends
        } else if let dayOfWeek = try? container.decode(Int.self, forKey: .weekly) {
            self = .weekly(dayOfWeek: dayOfWeek)
        } else if let dayOfWeek = try? container.decode(Int.self, forKey: .biweekly) {
            self = .biweekly(dayOfWeek: dayOfWeek)
        } else if let dayOfMonth = try? container.decode(Int.self, forKey: .monthly) {
            self = .monthly(dayOfMonth: dayOfMonth)
        } else if let daysOfWeek = try? container.decode([Int].self, forKey: .custom) {
            self = .custom(daysOfWeek: daysOfWeek)
        } else {
            self = .daily  // 默认值
        }
    }
}

// MARK: - Recurring Task

/// 周期性/重复任务
struct RecurringTask: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String

    // 基础任务模板
    var title: String
    var description: String?
    var category: TaskCategory
    var priority: TaskPriority
    var estimatedMinutes: Int?

    // 重复配置
    var recurrenceRule: RecurrenceRule
    var startDate: Date
    var endDate: Date?  // nil = 永久重复

    // 生成的任务
    var generatedInstanceIds: [String] = []  // 已生成的 Task ID
    var nextGenerationDate: Date             // 下一次应该生成的日期
    var lastGeneratedDate: Date?             // 最后一次生成的日期

    // 例外处理
    var skipDates: [Date] = []               // 跳过的日期

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, title, description, category, priority, estimatedMinutes
        case recurrenceRule, startDate, endDate
        case generatedInstanceIds, nextGenerationDate, lastGeneratedDate
        case skipDates, createdAt, updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        title: String,
        description: String? = nil,
        category: TaskCategory,
        priority: TaskPriority = .medium,
        estimatedMinutes: Int? = nil,
        recurrenceRule: RecurrenceRule,
        startDate: Date,
        endDate: Date? = nil,
        nextGenerationDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.recurrenceRule = recurrenceRule
        self.startDate = startDate
        self.endDate = endDate
        self.nextGenerationDate = nextGenerationDate ?? startDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
