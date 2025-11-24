import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import UserNotifications

// MARK: - Task Reminder Models

/// 提醒类型
enum ReminderType: String, Codable, CaseIterable {
    case beforeStart      // 任务开始前
    case beforeDeadline   // deadline 前
    case atStartTime      // 任务开始时
    case oneDayBefore     // 一天前
    case custom           // 自定义时间

    var displayName: String {
        switch self {
        case .beforeStart: return "开始前提醒"
        case .beforeDeadline: return "截止前提醒"
        case .atStartTime: return "开始时提醒"
        case .oneDayBefore: return "一天前提醒"
        case .custom: return "自定义时间提醒"
        }
    }
}

/// 通知方式
enum NotificationMethod: String, Codable, CaseIterable {
    case push      // Push notification
    case email     // 邮件
    case inApp     // App 内通知
    case all       // 全部

    var displayName: String {
        switch self {
        case .push: return "推送通知"
        case .email: return "邮件"
        case .inApp: return "应用内通知"
        case .all: return "全部方式"
        }
    }
}

/// 任务提醒
struct TaskReminder: Codable, Identifiable {
    @DocumentID var id: String?
    let taskId: String
    let userId: String

    let type: ReminderType
    let minutesBefore: Int  // 提前多少分钟（对于 beforeStart 和 beforeDeadline）

    var isEnabled: Bool = true
    let notificationMethod: NotificationMethod

    var lastSentAt: Date?
    var nextTriggerAt: Date?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, taskId, userId, type, minutesBefore, isEnabled
        case notificationMethod, lastSentAt, nextTriggerAt
        case createdAt, updatedAt
    }

    init(
        id: String? = nil,
        taskId: String,
        userId: String,
        type: ReminderType,
        minutesBefore: Int = 15,
        isEnabled: Bool = true,
        notificationMethod: NotificationMethod = .push,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.type = type
        self.minutesBefore = minutesBefore
        self.isEnabled = isEnabled
        self.notificationMethod = notificationMethod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Reminder Helper Models

/// 提醒触发信息（用于通知）
struct ReminderNotification {
    let taskTitle: String
    let reminderType: ReminderType
    let minutesBefore: Int
    let taskId: String

    var notificationTitle: String {
        switch reminderType {
        case .beforeStart:
            return "📌 任务即将开始"
        case .beforeDeadline:
            return "⏰ 任务即将截止"
        case .atStartTime:
            return "▶️ 现在开始任务"
        case .oneDayBefore:
            return "📅 任务提醒"
        case .custom:
            return "🔔 任务提醒"
        }
    }

    var notificationBody: String {
        switch reminderType {
        case .beforeStart:
            return "\"\(taskTitle)\" 将在 \(minutesBefore) 分钟后开始"
        case .beforeDeadline:
            return "\"\(taskTitle)\" 还有 \(minutesBefore) 分钟截止"
        case .atStartTime:
            return "现在开始任务：\(taskTitle)"
        case .oneDayBefore:
            return "\"\(taskTitle)\" 明天截止"
        case .custom:
            return "任务：\(taskTitle)"
        }
    }
}
