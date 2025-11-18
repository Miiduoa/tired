import Foundation
import FirebaseFirestore

// MARK: - Task (核心任务模型)

struct Task: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String

    // 任务来源
    var sourceOrgId: String?
    var sourceAppInstanceId: String?
    var sourceType: TaskSourceType

    // 基本信息
    var title: String
    var description: String?

    // 分类与优先级
    var category: TaskCategory
    var priority: TaskPriority

    // 时间管理
    var deadlineAt: Date?
    var estimatedMinutes: Int?

    // 排程
    var plannedDate: Date?
    var isDateLocked: Bool

    // 完成状态
    var isDone: Bool
    var doneAt: Date?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case sourceOrgId
        case sourceAppInstanceId
        case sourceType
        case title
        case description
        case category
        case priority
        case deadlineAt
        case estimatedMinutes
        case plannedDate
        case isDateLocked
        case isDone
        case doneAt
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        sourceOrgId: String? = nil,
        sourceAppInstanceId: String? = nil,
        sourceType: TaskSourceType = .manual,
        title: String,
        description: String? = nil,
        category: TaskCategory,
        priority: TaskPriority = .medium,
        deadlineAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        plannedDate: Date? = nil,
        isDateLocked: Bool = false,
        isDone: Bool = false,
        doneAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.sourceOrgId = sourceOrgId
        self.sourceAppInstanceId = sourceAppInstanceId
        self.sourceType = sourceType
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.deadlineAt = deadlineAt
        self.estimatedMinutes = estimatedMinutes
        self.plannedDate = plannedDate
        self.isDateLocked = isDateLocked
        self.isDone = isDone
        self.doneAt = doneAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Extensions

extension Task {
    /// 是否已过期
    var isOverdue: Bool {
        guard let deadline = deadlineAt, !isDone else { return false }
        return deadline < Date()
    }

    /// 估计小时数
    var estimatedHours: Double? {
        guard let minutes = estimatedMinutes else { return nil }
        return Double(minutes) / 60.0
    }

    /// 是否为今天的任务
    func isToday() -> Bool {
        guard let planned = plannedDate else {
            // 如果没有排程日期，检查是否deadline是今天
            guard let deadline = deadlineAt else { return false }
            return Calendar.current.isDateInToday(deadline)
        }
        return Calendar.current.isDateInToday(planned)
    }

    /// 是否在本周
    func isThisWeek() -> Bool {
        guard let planned = plannedDate else { return false }
        return Calendar.current.isDate(planned, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// 是否未排程（Backlog）
    var isBacklog: Bool {
        return plannedDate == nil && !isDone
    }
}

// MARK: - TaskWithOrg (用于UI显示)

struct TaskWithOrg: Identifiable {
    let task: Task
    let organization: Organization?

    var id: String? { task.id }
}
