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

    // ✅ 新增：子任務與里程碑功能
    var parentTaskId: String?        // 父任務 ID（如果是子任務）
    var subtaskIds: [String] = []    // 子任務 ID 列表
    var isMilestone: Bool = false    // 是否是里程碑

    // ✅ 新增：標籤系統
    var tagIds: [String] = []        // 標籤 ID 列表

    // ✅ 新增：依賴關係
    var dependsOnTaskIds: [String] = []  // 前置任務 ID 列表

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
        case parentTaskId
        case subtaskIds
        case isMilestone
        case tagIds
        case dependsOnTaskIds
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
        comments: [TaskComment]? = nil,
        fileAttachments: [FileAttachment]? = nil,
        parentTaskId: String? = nil,      // ✅ 新增
        subtaskIds: [String] = [],        // ✅ 新增
        isMilestone: Bool = false,        // ✅ 新增
        tagIds: [String] = [],            // ✅ 新增
        dependsOnTaskIds: [String] = [],  // ✅ 新增
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
        self.comments = comments
        self.fileAttachments = fileAttachments
        self.parentTaskId = parentTaskId        // ✅ 新增
        self.subtaskIds = subtaskIds            // ✅ 新增
        self.isMilestone = isMilestone          // ✅ 新增
        self.tagIds = tagIds                    // ✅ 新增
        self.dependsOnTaskIds = dependsOnTaskIds  // ✅ 新增
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
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return false
        }

        // 检查是否有排期在本周
        if let planned = plannedDate, weekInterval.contains(planned) {
            return true
        }

        // 检查 deadline 是否在本周 ✅ 关键修复：遗漏的任务会被包含
        if let deadline = deadlineAt, weekInterval.contains(deadline) {
            return true
        }

        return false
    }

    /// 是否未排程（Backlog）
    var isBacklog: Bool {
        return plannedDate == nil && !isDone
    }

    /// 是否逾期或紧急 ✅ 新增：用于标记需要立即关注的任务
    var isOverdueOrUrgent: Bool {
        guard let deadline = deadlineAt, !isDone else { return false }
        return deadline <= Date()
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

