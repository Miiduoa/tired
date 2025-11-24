import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Task (核心任務模型)

struct Task: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String

    // 任務來源
    var sourceOrgId: String?
    var sourceAppInstanceId: String?
    var sourceType: TaskSourceType

    // 基本信息
    var title: String
    var description: String?

    // 分類與優先級
    var category: TaskCategory
    var priority: TaskPriority

    // 時間管理
    var deadlineAt: Date?
    var estimatedMinutes: Int?

    // 排程
    var plannedDate: Date?
    var isDateLocked: Bool

    // 完成狀態
    var isDone: Bool
    var doneAt: Date?

    // 新增：評論與附件
    var comments: [TaskComment]?
    var fileAttachments: [FileAttachment]?

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
        case comments
        case fileAttachments
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
        comments: [TaskComment]? = nil, // 新增
        fileAttachments: [FileAttachment]? = nil, // 新增
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
        self.comments = comments // 新增
        self.fileAttachments = fileAttachments // 新增
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Extensions

extension Task {
    /// 是否已過期
    var isOverdue: Bool {
        guard let deadline = deadlineAt, !isDone else { return false }
        return deadline < Date()
    }

    /// 估計小時數
    var estimatedHours: Double? {
        guard let minutes = estimatedMinutes else { return nil }
        return Double(minutes) / 60.0
    }

    /// 是否為今天的任務
    func isToday() -> Bool {
        guard let planned = plannedDate else {
            // 如果沒有排程日期，檢查是否deadline是今天
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

// MARK: - Helper Models for Task

/// 任務評論結構
struct TaskComment: Codable, Identifiable, Hashable {
    let id: String = UUID().uuidString
    let authorUserId: String
    var content: String
    let createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // For UI Display
    var author: UserProfile?
}

/// 文件附件結構
struct FileAttachment: Codable, Identifiable, Hashable {
    let id: String = UUID().uuidString
    let fileName: String
    let fileUrl: String
    let fileType: String // e.g., "image/jpeg", "application/pdf"
    let uploadedByUserId: String
    let uploadedAt: Date = Date()
}

