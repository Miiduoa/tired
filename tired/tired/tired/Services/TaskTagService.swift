import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

// MARK: - Task Tag Model

/// 任务标签
struct TaskTag: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let userId: String  // 用户自定义的标签

    var name: String         // 如 "#紧急"
    var color: String?       // 十六进制颜色
    var icon: String?        // SF Symbol 图标
    var description: String?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, name, color, icon, description, createdAt, updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TaskTag, rhs: TaskTag) -> Bool {
        return lhs.id == rhs.id
    }

    init(
        id: String? = nil,
        userId: String,
        name: String,
        color: String? = nil,
        icon: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.icon = icon
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Tag Service

/// 任务标签服务
class TaskTagService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Tags

    /// 获取用户的所有标签（实时监听）
    func fetchUserTags(userId: String) -> AnyPublisher<[TaskTag], Error> {
        let subject = PassthroughSubject<[TaskTag], Error>()

        db.collection("taskTags")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let tags = documents.compactMap { doc -> TaskTag? in
                    try? doc.data(as: TaskTag.self)
                }

                subject.send(tags)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取特定标签
    func fetchTag(id: String) async throws -> TaskTag {
        let doc = try await db.collection("taskTags").document(id).getDocument()
        guard let tag = try? doc.data(as: TaskTag.self) else {
            throw NSError(domain: "TaskTagService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tag not found"])
        }
        return tag
    }

    // MARK: - Create/Update/Delete Tags

    /// 创建标签
    func createTag(_ tag: TaskTag) async throws -> String {
        var newTag = tag
        newTag.createdAt = Date()
        newTag.updatedAt = Date()

        let docRef = try db.collection("taskTags").addDocument(from: newTag)
        return docRef.documentID
    }

    /// 更新标签
    func updateTag(_ tag: TaskTag) async throws {
        guard let id = tag.id else {
            throw NSError(domain: "TaskTagService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tag ID is missing"])
        }

        var updatedTag = tag
        updatedTag.updatedAt = Date()

        try db.collection("taskTags").document(id).setData(from: updatedTag)
    }

    /// 删除标签
    func deleteTag(id: String) async throws {
        try await db.collection("taskTags").document(id).delete()
    }

    // MARK: - Tag-Task Operations

    /// 将标签添加到任务
    func addTagToTask(_ tagId: String, taskId: String) async throws {
        let taskRef = db.collection("tasks").document(taskId)

        try await taskRef.updateData([
            "tagIds": FieldValue.arrayUnion([tagId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 从任务中移除标签
    func removeTagFromTask(_ tagId: String, taskId: String) async throws {
        let taskRef = db.collection("tasks").document(taskId)

        try await taskRef.updateData([
            "tagIds": FieldValue.arrayRemove([tagId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 搜索带有特定标签的任务
    func searchTasksByTag(_ tagId: String, userId: String) async throws -> [Task] {
        let snapshot = try await db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Task? in
            guard let task = try? doc.data(as: Task.self),
                  task.tagIds.contains(tagId) else {
                return nil
            }
            return task
        }
    }
}
