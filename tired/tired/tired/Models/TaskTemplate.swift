import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 任務模板模型
struct TaskTemplate: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var description: String?
    var category: TaskCategory
    var priority: TaskPriority
    var estimatedMinutes: Int?
    var descriptionTemplate: String?
    var tags: [String]?
    var subtasks: [SubtaskTemplate]?
    var reminderEnabled: Bool
    var recurrence: TaskRecurrence?
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    init(
        id: String? = nil,
        userId: String,
        name: String,
        description: String? = nil,
        category: TaskCategory,
        priority: TaskPriority = .medium,
        estimatedMinutes: Int? = nil,
        descriptionTemplate: String? = nil,
        tags: [String]? = nil,
        subtasks: [SubtaskTemplate]? = nil,
        reminderEnabled: Bool = false,
        recurrence: TaskRecurrence? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.category = category
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.descriptionTemplate = descriptionTemplate
        self.tags = tags
        self.subtasks = subtasks
        self.reminderEnabled = reminderEnabled
        self.recurrence = recurrence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
    }

    /// 子任務模板結構
    struct SubtaskTemplate: Codable, Hashable {
        var title: String
        var estimatedMinutes: Int?

        init(title: String, estimatedMinutes: Int? = nil) {
            self.title = title
            self.estimatedMinutes = estimatedMinutes
        }
    }

    /// 模板使用統計
    var usageStats: String {
        if usageCount == 0 {
            return "尚未使用"
        } else if usageCount == 1 {
            return "已使用 1 次"
        } else {
            return "已使用 \(usageCount) 次"
        }
    }

    /// 估計時間描述
    var estimatedTimeDescription: String {
        guard let minutes = estimatedMinutes else { return "未設定時間" }
        if minutes < 60 {
            return "\(minutes) 分鐘"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) 小時"
            } else {
                return "\(hours) 小時 \(remainingMinutes) 分鐘"
            }
        }
    }

    /// 是否為預設模板
    var isDefaultTemplate: Bool {
        return userId == "system"
    }

    /// 模板摘要資訊
    var summary: String {
        var parts: [String] = []

        parts.append(category.displayName)

        if let minutes = estimatedMinutes {
            if minutes < 60 {
                parts.append("\(minutes)分鐘")
            } else {
                parts.append("\(minutes / 60)小時")
            }
        }

        if let tags = tags, !tags.isEmpty {
            parts.append(tags.joined(separator: "、"))
        }

        return parts.joined(separator: " · ")
    }

    /// 複製模板
    func copy(withNewName name: String) -> TaskTemplate {
        var copy = self
        copy.id = nil
        copy.name = name
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.usageCount = 0
        return copy
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(userId)
        hasher.combine(name)
    }

    static func == (lhs: TaskTemplate, rhs: TaskTemplate) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.name == rhs.name &&
               lhs.updatedAt == rhs.updatedAt
    }
}

// MARK: - 模板分類

extension TaskTemplate {
    /// 獲取預設模板的分類
    static func getDefaultTemplatesByCategory() -> [TaskCategory: [TaskTemplate]] {
        let service = TaskTemplateService()
        let templates = service.getDefaultTemplates()

        return Dictionary(grouping: templates, by: { $0.category })
    }

    /// 獲取最受歡迎的模板（基於使用次數）
    static func getPopularTemplates(from templates: [TaskTemplate], limit: Int = 10) -> [TaskTemplate] {
        return templates.sorted { $0.usageCount > $1.usageCount }.prefix(limit).map { $0 }
    }

    /// 獲取最近更新的模板
    static func getRecentlyUpdatedTemplates(from templates: [TaskTemplate], limit: Int = 10) -> [TaskTemplate] {
        return templates.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit).map { $0 }
    }

    /// 根據關鍵字過濾模板
    static func filterTemplates(_ templates: [TaskTemplate], by keyword: String) -> [TaskTemplate] {
        guard !keyword.isEmpty else { return templates }

        let lowerKeyword = keyword.lowercased()
        return templates.filter { template in
            template.name.lowercased().contains(lowerKeyword) ||
            (template.description?.lowercased().contains(lowerKeyword) ?? false) ||
            (template.tags?.contains(where: { $0.lowercased().contains(lowerKeyword) }) ?? false)
        }
    }
}

// MARK: - 模板創建建議

extension TaskTemplate {
    /// 根據任務歷史分析建議的模板
    static func suggestTemplatesFromTaskHistory(tasks: [Task], userId: String) -> [TemplateSuggestion] {
        // 分析重複任務模式
        let taskTitles = tasks.map { $0.title }
        var titleCounts: [String: Int] = [:]

        for title in taskTitles {
            titleCounts[title, default: 0] += 1
        }

        // 找出重複3次以上的任務
        let repeatedTasks = titleCounts.filter { $0.value >= 3 }.keys

        return repeatedTasks.map { title in
            let sampleTasks = tasks.filter { $0.title == title }
            let avgMinutes = sampleTasks.map { $0.actualMinutes ?? $0.estimatedMinutes ?? 0 }.reduce(0, +) / sampleTasks.count
            let mostCommonCategory = sampleTasks
                .reduce(into: [TaskCategory: Int]()) { counts, task in
                    counts[task.category, default: 0] += 1
                }
                .max(by: { $0.value < $1.value })?.key ?? .personal

            return TemplateSuggestion(
                title: title,
                suggestedName: title,
                category: mostCommonCategory,
                estimatedMinutes: avgMinutes,
                frequency: sampleTasks.count,
                reason: "這個任務重複執行了 \(sampleTasks.count) 次，建議建立模板"
            )
        }
    }
}

/// 模板建議結構
struct TemplateSuggestion {
    let title: String
    let suggestedName: String
    let category: TaskCategory
    let estimatedMinutes: Int
    let frequency: Int
    let reason: String
}