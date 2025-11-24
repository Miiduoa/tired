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
    var tags: [String]?  // 自定義標籤

    // 時間管理
    var deadlineAt: Date?
    var estimatedMinutes: Int?
    var actualMinutes: Int?  // 實際花費時間

    // 排程
    var plannedDate: Date?
    var plannedStartTime: Date?  // 具體開始時間
    var isDateLocked: Bool

    // 完成狀態
    var isDone: Bool
    var doneAt: Date?
    var completionPercentage: Int?  // 完成百分比 (0-100)

    // 子任務
    var subtasks: [Subtask]?
    var parentTaskId: String?  // 如果這是子任務，記錄父任務ID

    // 重複任務
    var recurrence: TaskRecurrence?
    var recurrenceParentId: String?  // 重複任務的父任務ID

    // 專注模式相關
    var focusSessions: [FocusSession]?  // 番茄鐘記錄
    var totalFocusMinutes: Int?  // 總專注時間

    // 提醒設定
    var reminderAt: Date?
    var reminderEnabled: Bool?

    // 評論與附件
    var comments: [TaskComment]?
    var fileAttachments: [FileAttachment]?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId
        case sourceOrgId, sourceAppInstanceId, sourceType
        case title, description
        case category, priority, tags
        case deadlineAt, estimatedMinutes, actualMinutes
        case plannedDate, plannedStartTime, isDateLocked
        case isDone, doneAt, completionPercentage
        case subtasks, parentTaskId
        case recurrence, recurrenceParentId
        case focusSessions, totalFocusMinutes
        case reminderAt, reminderEnabled
        case comments, fileAttachments
        case createdAt, updatedAt
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
        tags: [String]? = nil,
        deadlineAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        plannedDate: Date? = nil,
        plannedStartTime: Date? = nil,
        isDateLocked: Bool = false,
        isDone: Bool = false,
        doneAt: Date? = nil,
        completionPercentage: Int? = nil,
        subtasks: [Subtask]? = nil,
        parentTaskId: String? = nil,
        recurrence: TaskRecurrence? = nil,
        recurrenceParentId: String? = nil,
        focusSessions: [FocusSession]? = nil,
        totalFocusMinutes: Int? = nil,
        reminderAt: Date? = nil,
        reminderEnabled: Bool? = nil,
        comments: [TaskComment]? = nil,
        fileAttachments: [FileAttachment]? = nil,
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
        self.tags = tags
        self.deadlineAt = deadlineAt
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.plannedDate = plannedDate
        self.plannedStartTime = plannedStartTime
        self.isDateLocked = isDateLocked
        self.isDone = isDone
        self.doneAt = doneAt
        self.completionPercentage = completionPercentage
        self.subtasks = subtasks
        self.parentTaskId = parentTaskId
        self.recurrence = recurrence
        self.recurrenceParentId = recurrenceParentId
        self.focusSessions = focusSessions
        self.totalFocusMinutes = totalFocusMinutes
        self.reminderAt = reminderAt
        self.reminderEnabled = reminderEnabled
        self.comments = comments
        self.fileAttachments = fileAttachments
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

    /// 是否即將到期（24小時內）
    var isDueSoon: Bool {
        guard let deadline = deadlineAt, !isDone else { return false }
        let hoursUntilDeadline = deadline.timeIntervalSince(Date()) / 3600
        return hoursUntilDeadline > 0 && hoursUntilDeadline <= 24
    }

    /// 距離截止日期的天數（負數表示已過期）
    var daysUntilDeadline: Int? {
        guard let deadline = deadlineAt else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }

    /// 估計小時數
    var estimatedHours: Double? {
        guard let minutes = estimatedMinutes else { return nil }
        return Double(minutes) / 60.0
    }

    /// 是否為今天的任務
    func isToday() -> Bool {
        guard let planned = plannedDate else {
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

    /// 子任務完成進度
    var subtaskProgress: Double {
        guard let subtasks = subtasks, !subtasks.isEmpty else {
            return isDone ? 1.0 : 0.0
        }
        let completed = subtasks.filter { $0.isDone }.count
        return Double(completed) / Double(subtasks.count)
    }

    /// 子任務完成數量
    var completedSubtaskCount: Int {
        return subtasks?.filter { $0.isDone }.count ?? 0
    }

    /// 子任務總數量
    var totalSubtaskCount: Int {
        return subtasks?.count ?? 0
    }

    /// 任務緊急程度分數（用於排序）
    var urgencyScore: Int {
        var score = 0

        // 優先級分數
        switch priority {
        case .high: score += 30
        case .medium: score += 20
        case .low: score += 10
        }

        // 截止日期分數
        if isOverdue {
            score += 50
        } else if isDueSoon {
            score += 40
        } else if let days = daysUntilDeadline {
            if days <= 3 { score += 25 }
            else if days <= 7 { score += 15 }
        }

        return score
    }

    /// 狀態描述
    var statusDescription: String {
        if isDone { return "已完成" }
        if isOverdue { return "已過期" }
        if isDueSoon { return "即將到期" }
        if let days = daysUntilDeadline, days <= 3 { return "緊急" }
        return "進行中"
    }

    /// 狀態顏色
    var statusColor: String {
        if isDone { return "#10B981" }  // 綠色
        if isOverdue { return "#EF4444" }  // 紅色
        if isDueSoon { return "#F59E0B" }  // 橙色
        if priority == .high { return "#DC2626" }  // 深紅
        return "#6B7280"  // 灰色
    }
}

// MARK: - Subtask Model

/// 子任務結構
struct Subtask: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false
    var doneAt: Date?
    var sortOrder: Int = 0

    init(id: String = UUID().uuidString, title: String, isDone: Bool = false, doneAt: Date? = nil, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.doneAt = doneAt
        self.sortOrder = sortOrder
    }
}

// MARK: - Task Recurrence Model

/// 任務重複設定
struct TaskRecurrence: Codable, Hashable {
    var type: RecurrenceType
    var interval: Int  // 間隔數量（例如：每2天、每3週）
    var endDate: Date?  // 結束日期
    var occurrences: Int?  // 重複次數
    var weekdays: [Int]?  // 每週的哪幾天（1=週日, 2=週一, ..., 7=週六）
    var monthDay: Int?  // 每月的哪一天

    enum RecurrenceType: String, Codable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case biweekly = "biweekly"
        case monthly = "monthly"
        case yearly = "yearly"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .daily: return "每天"
            case .weekly: return "每週"
            case .biweekly: return "每兩週"
            case .monthly: return "每月"
            case .yearly: return "每年"
            case .custom: return "自定義"
            }
        }
    }

    /// 計算下一次發生日期
    func nextOccurrence(from date: Date) -> Date? {
        let calendar = Calendar.current

        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        case .custom:
            return calendar.date(byAdding: .day, value: interval, to: date)
        }
    }
}

// MARK: - Focus Session Model

/// 專注時段記錄（番茄鐘）
struct FocusSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var startTime: Date
    var endTime: Date?
    var durationMinutes: Int  // 預設25分鐘
    var breakMinutes: Int = 5  // 休息時間
    var isCompleted: Bool = false
    var notes: String?

    init(
        id: String = UUID().uuidString,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationMinutes: Int = 25,
        breakMinutes: Int = 5,
        isCompleted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.breakMinutes = breakMinutes
        self.isCompleted = isCompleted
        self.notes = notes
    }

    /// 實際專注時間（分鐘）
    var actualMinutes: Int {
        guard let end = endTime else {
            return Int(Date().timeIntervalSince(startTime) / 60)
        }
        return Int(end.timeIntervalSince(startTime) / 60)
    }
}

// MARK: - Task Comment Model

/// 任務評論結構
struct TaskComment: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    let authorUserId: String
    var content: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // For UI Display (不存儲到 Firestore)
    var author: UserProfile?

    enum CodingKeys: String, CodingKey {
        case id, authorUserId, content, createdAt, updatedAt
    }

    init(id: String = UUID().uuidString, authorUserId: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date(), author: UserProfile? = nil) {
        self.id = id
        self.authorUserId = authorUserId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
    }
}

// MARK: - File Attachment Model

/// 文件附件結構
struct FileAttachment: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    let fileName: String
    let fileUrl: String
    let fileType: String  // e.g., "image/jpeg", "application/pdf"
    let uploadedByUserId: String
    var uploadedAt: Date = Date()
    var fileSize: Int?  // 檔案大小（bytes）

    init(
        id: String = UUID().uuidString,
        fileName: String,
        fileUrl: String,
        fileType: String,
        uploadedByUserId: String,
        uploadedAt: Date = Date(),
        fileSize: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileUrl = fileUrl
        self.fileType = fileType
        self.uploadedByUserId = uploadedByUserId
        self.uploadedAt = uploadedAt
        self.fileSize = fileSize
    }
}

// MARK: - Task Sort Option

/// 任務排序選項
enum TaskSortOption: String, CaseIterable {
    case deadline = "截止日期"
    case priority = "優先級"
    case category = "分類"
    case created = "創建時間"
    case urgency = "緊急程度"

    var icon: String {
        switch self {
        case .deadline: return "calendar"
        case .priority: return "exclamationmark.triangle"
        case .category: return "folder"
        case .created: return "clock"
        case .urgency: return "flame"
        }
    }
}

