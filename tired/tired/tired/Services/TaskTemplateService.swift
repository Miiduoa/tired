import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

/// 任務模板服務
class TaskTemplateService {
    private let db = FirebaseManager.shared.db
    
    /// 獲取用戶模板
    func fetchUserTemplates(userId: String) async throws -> [TaskTemplate] {
        let snapshot = try await db.collection("taskTemplates")
            .whereField("userId", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: TaskTemplate.self)
        }
    }
    
    /// 獲取預設模板
    func getDefaultTemplates() -> [TaskTemplate] {
        // 返回一些預設模板
        return [
            TaskTemplate(
                userId: "system",
                name: "每日閱讀",
                description: "每天閱讀30分鐘",
                category: .personal,
                priority: .medium,
                estimatedMinutes: 30,
                tags: ["閱讀", "學習"],
                reminderEnabled: true
            ),
            TaskTemplate(
                userId: "system",
                name: "運動",
                description: "進行30分鐘運動",
                category: .personal,
                priority: .high,
                estimatedMinutes: 30,
                tags: ["運動", "健康"],
                reminderEnabled: true
            ),
            TaskTemplate(
                userId: "system",
                name: "工作會議",
                description: "參加工作會議",
                category: .work,
                priority: .high,
                estimatedMinutes: 60,
                tags: ["會議", "工作"],
                reminderEnabled: true
            ),
            TaskTemplate(
                userId: "system",
                name: "學習新技能",
                description: "學習新技能或技術",
                category: .school,
                priority: .medium,
                estimatedMinutes: 120,
                tags: ["學習", "技能"],
                reminderEnabled: false
            )
        ]
    }
    
    /// 推薦模板
    func recommendTemplates(for userId: String) async throws -> [TaskTemplate] {
        // 獲取用戶最常用的分類
        let userTasks = try await fetchUserTasks(userId: userId)
        let categoryCounts = Dictionary(grouping: userTasks, by: { $0.category })
            .mapValues { $0.count }
        
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key ?? .personal
        
        // 返回該分類的預設模板
        return getDefaultTemplates().filter { $0.category == topCategory }
    }
    
    /// 推薦模板（按分類）
    func recommendTemplates(for category: TaskCategory, userId: String) async throws -> [TaskTemplate] {
        return getDefaultTemplates().filter { $0.category == category }
    }
    
    /// 從任務創建模板
    func createTemplate(from task: Task, name: String, description: String? = nil) async throws -> TaskTemplate {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "TaskTemplateService", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }
        
        let subtaskTemplates = task.subtasks?.map { subtask in
            TaskTemplate.SubtaskTemplate(title: subtask.title, estimatedMinutes: nil)
        }
        
        let template = TaskTemplate(
            userId: userId,
            name: name,
            description: description ?? task.description,
            category: task.category,
            priority: task.priority,
            estimatedMinutes: task.estimatedMinutes,
            tags: task.tags,
            subtasks: subtaskTemplates,
            reminderEnabled: task.reminderEnabled ?? false
        )
        
        let ref = try db.collection("taskTemplates").addDocument(from: template)
        var savedTemplate = template
        savedTemplate.id = ref.documentID
        
        return savedTemplate
    }
    
    /// 從模板創建任務
    func createTaskFromTemplate(templateId: String, title: String? = nil, deadline: Date? = nil, plannedDate: Date? = nil) async throws -> Task {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "TaskTemplateService", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }
        
        let doc = try await db.collection("taskTemplates").document(templateId).getDocument()
        guard let template = try? doc.data(as: TaskTemplate.self) else {
            throw NSError(domain: "TaskTemplateService", code: -2, userInfo: [NSLocalizedDescriptionKey: "模板不存在"])
        }
        
        let subtasks = template.subtasks?.enumerated().map { index, subtaskTemplate in
            Subtask(title: subtaskTemplate.title, isDone: false, sortOrder: index)
        }
        
        let task = Task(
            userId: userId,
            sourceOrgId: nil,
            sourceAppInstanceId: nil,
            sourceType: .manual,
            taskType: .generic,
            title: title ?? template.name,
            description: template.description,
            assigneeUserIds: nil,
            category: template.category,
            priority: template.priority,
            tags: template.tags,
            deadlineAt: deadline,
            estimatedMinutes: template.estimatedMinutes,
            plannedDate: plannedDate,
            plannedStartTime: nil,
            isDateLocked: plannedDate != nil,
            subtasks: subtasks,
            reminderAt: nil,
            reminderEnabled: template.reminderEnabled
        )
        
        // 更新模板使用次數
        try await db.collection("taskTemplates").document(templateId).updateData([
            "usageCount": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])
        
        return task
    }
    
    /// 刪除模板
    func deleteTemplate(id: String) async throws {
        try await db.collection("taskTemplates").document(id).delete()
    }
    
    /// 更新模板
    func updateTemplate(_ template: TaskTemplate) async throws {
        guard let id = template.id else {
            throw NSError(domain: "TaskTemplateService", code: -1, userInfo: [NSLocalizedDescriptionKey: "模板ID不存在"])
        }
        
        var updatedTemplate = template
        updatedTemplate.updatedAt = Date()
        
        try db.collection("taskTemplates").document(id).setData(from: updatedTemplate, merge: true)
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserTasks(userId: String) async throws -> [Task] {
        let snapshot = try await db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Task.self)
        }
    }
}

