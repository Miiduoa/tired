import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Task Achievement Model ✅ 新增：成就系统

/// 成就类型
enum AchievementType: String, Codable {
    case firstTaskCompleted = "first_task"
    case fiveTasksCompleted = "five_tasks"
    case tenTasksCompleted = "ten_tasks"
    case fiftyTasksCompleted = "fifty_tasks"
    case hundredTasksCompleted = "hundred_tasks"
    case seventyPercentCompletion = "seventy_percent"
    case onTimeStreak = "on_time_streak"
    case highPriorityFocus = "high_priority_focus"
}

/// 用户成就
struct TaskAchievement: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let userId: String?  // 可选：用于系统级成就时不需要

    let type: AchievementType
    let title: String        // "初出茅庐"
    let description: String  // "完成第一个任务"
    let icon: String        // "🌱"

    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, type, title, description, icon, earnedAt
    }

    // Identifiable 和 Hashable 协议
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TaskAchievement, rhs: TaskAchievement) -> Bool {
        return lhs.id == rhs.id
    }

    init(
        id: String? = nil,
        userId: String? = nil,
        type: AchievementType,
        title: String,
        description: String,
        icon: String,
        earnedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.description = description
        self.icon = icon
        self.earnedAt = earnedAt
    }
}
