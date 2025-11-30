import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 任務模板視圖模型
class TaskTemplateViewModel: ObservableObject {
    @Published var templates: [TaskTemplate] = []
    @Published var recommendedTemplates: [TaskTemplate] = []
    @Published var defaultTemplates: [TaskTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let templateService = TaskTemplateService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        loadDefaultTemplates()
    }

    /// 載入用戶模板
    func loadUserTemplates() {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            return
        }

        isLoading = true
        errorMessage = nil

        _Concurrency.Task {
            do {
                let userTemplates = try await templateService.fetchUserTemplates(userId: userId)
                await MainActor.run {
                    self.templates = userTemplates
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "載入模板失敗：\(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    /// 載入推薦模板
    func loadRecommendedTemplates() {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                let recommended = try await templateService.recommendTemplates(for: userId)
                await MainActor.run {
                    self.recommendedTemplates = recommended
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "載入推薦模板失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 載入預設模板
    func loadDefaultTemplates() {
        defaultTemplates = templateService.getDefaultTemplates()
    }

    /// 從任務創建模板
    func createTemplate(from task: Task, name: String, description: String? = nil) async throws -> TaskTemplate {
        let template = try await templateService.createTemplate(from: task, name: name, description: description)
        await MainActor.run {
            self.templates.insert(template, at: 0)
        }
        return template
    }

    /// 從模板創建任務
    func createTaskFromTemplate(templateId: String, title: String? = nil, deadline: Date? = nil, plannedDate: Date? = nil) async throws -> Task {
        return try await templateService.createTaskFromTemplate(templateId: templateId, title: title, deadline: deadline, plannedDate: plannedDate)
    }

    /// 刪除模板
    func deleteTemplate(templateId: String) async {
        do {
            try await templateService.deleteTemplate(id: templateId)
            await MainActor.run {
                self.templates.removeAll { $0.id == templateId }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "刪除模板失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 更新模板
    func updateTemplate(_ template: TaskTemplate) async {
        do {
            try await templateService.updateTemplate(template)
            await MainActor.run {
                if let index = self.templates.firstIndex(where: { $0.id == template.id }) {
                    self.templates[index] = template
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "更新模板失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 根據分類獲取模板
    func getTemplates(for category: TaskCategory) -> [TaskTemplate] {
        return templates.filter { $0.category == category }
    }

    /// 搜索模板
    func searchTemplates(query: String) -> [TaskTemplate] {
        let allTemplates = templates + defaultTemplates
        guard !query.isEmpty else { return allTemplates }

        let lowerQuery = query.lowercased()
        return allTemplates.filter { template in
            template.name.lowercased().contains(lowerQuery) ||
            (template.description?.lowercased().contains(lowerQuery) ?? false) ||
            (template.tags?.contains(where: { $0.lowercased().contains(lowerQuery) }) ?? false)
        }
    }

    /// 獲取最常用的模板
    func getMostUsedTemplates(limit: Int = 5) -> [TaskTemplate] {
        return templates.sorted { $0.usageCount > $1.usageCount }.prefix(limit).map { $0 }
    }

    /// 獲取最近使用的模板
    func getRecentlyUsedTemplates(limit: Int = 5) -> [TaskTemplate] {
        return templates.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit).map { $0 }
    }

    /// 根據分類獲取推薦模板
    func getRecommendedTemplates(for category: TaskCategory) async {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                let recommended = try await templateService.recommendTemplates(for: category, userId: userId)
                await MainActor.run {
                    self.recommendedTemplates = recommended
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "載入分類推薦模板失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 批量創建任務從模板
    func createTasksFromTemplates(templateIds: [String], dateRange: ClosedRange<Date>? = nil) async throws -> [Task] {
        var tasks: [Task] = []

        for templateId in templateIds {
            let task = try await createTaskFromTemplate(templateId: templateId)

            // 如果有日期範圍，平均分配任務
            if let dateRange = dateRange {
                let dayCount = Calendar.current.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 1
                let randomOffset = Int.random(in: 0..<max(1, dayCount))
                if let plannedDate = Calendar.current.date(byAdding: .day, value: randomOffset, to: dateRange.lowerBound) {
                    var updatedTask = task
                    updatedTask.plannedDate = plannedDate
                    tasks.append(updatedTask)
                } else {
                    tasks.append(task)
                }
            } else {
                tasks.append(task)
            }
        }

        return tasks
    }

    /// 複製模板
    func duplicateTemplate(_ template: TaskTemplate, newName: String) async throws -> TaskTemplate {
        var newTemplate = template
        newTemplate.id = nil
        newTemplate.name = newName
        newTemplate.createdAt = Date()
        newTemplate.updatedAt = Date()
        newTemplate.usageCount = 0

        let ref = try FirebaseManager.shared.db.collection("taskTemplates").addDocument(from: newTemplate)
        newTemplate.id = ref.documentID

        await MainActor.run {
            self.templates.insert(newTemplate, at: 0)
        }

        return newTemplate
    }

    /// 匯出模板為JSON
    func exportTemplateAsJSON(_ template: TaskTemplate) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(template)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// 從JSON匯入模板
    func importTemplateFromJSON(_ jsonString: String) async throws -> TaskTemplate {
        guard let userId = userId else {
            throw NSError(domain: "TaskTemplateViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var template = try decoder.decode(TaskTemplate.self, from: Data(jsonString.utf8))
        template.id = nil
        template.userId = userId
        template.createdAt = Date()
        template.updatedAt = Date()
        template.usageCount = 0

        let ref = try FirebaseManager.shared.db.collection("taskTemplates").addDocument(from: template)
        template.id = ref.documentID

        await MainActor.run {
            self.templates.insert(template, at: 0)
        }

        return template
    }
}