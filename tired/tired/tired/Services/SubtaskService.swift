import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 子任务服务
class SubtaskService: ObservableObject {
    private let db = FirebaseManager.shared.db
    private let taskService = TaskService()

    // MARK: - Fetch Subtasks

    /// 获取任务的所有子任务
    func fetchSubtasks(parentTaskId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        db.collection("tasks")
            .whereField("parentTaskId", isEqualTo: parentTaskId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let subtasks = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                subject.send(subtasks)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Manage Subtasks

    /// 添加子任务到父任务
    func addSubtask(_ subtask: Task, to parentTaskId: String) async throws {
        var newSubtask = subtask
        newSubtask.parentTaskId = parentTaskId

        // 创建子任务
        let docRef = try db.collection("tasks").addDocument(from: newSubtask)

        // 更新父任务的子任务列表
        let parentRef = db.collection("tasks").document(parentTaskId)
        try await parentRef.updateData([
            "subtaskIds": FieldValue.arrayUnion([docRef.documentID]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 移除子任务
    func removeSubtask(_ subtaskId: String, from parentTaskId: String) async throws {
        // 删除子任务
        try await taskService.deleteTask(id: subtaskId)

        // 更新父任务的子任务列表
        let parentRef = db.collection("tasks").document(parentTaskId)
        try await parentRef.updateData([
            "subtaskIds": FieldValue.arrayRemove([subtaskId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Progress Tracking

    /// 计算父任务的完成百分比
    func calculateParentProgress(parentTaskId: String) async throws -> Int {
        let snapshot = try await db.collection("tasks")
            .whereField("parentTaskId", isEqualTo: parentTaskId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return 0 }

        let subtasks = snapshot.documents.compactMap { doc -> Task? in
            try? doc.data(as: Task.self)
        }

        let completedCount = subtasks.filter { $0.isDone }.count
        return (completedCount * 100) / subtasks.count
    }

    /// 当子任务完成时更新父任务
    func updateParentOnSubtaskCompletion(childTaskId: String) async throws {
        // 获取子任务
        let childDoc = try await db.collection("tasks").document(childTaskId).getDocument()
        guard let childTask = try? childDoc.data(as: Task.self),
              let parentId = childTask.parentTaskId else { return }

        // 获取父任务
        let parentDoc = try await db.collection("tasks").document(parentId).getDocument()
        guard var parentTask = try? parentDoc.data(as: Task.self) else { return }

        // 计算新的进度
        let progress = try await calculateParentProgress(parentTaskId: parentId)

        // 如果所有子任务都完成，自动完成父任务
        if progress == 100 && !parentTask.isDone {
            parentTask.isDone = true
            parentTask.doneAt = Date()
            try await taskService.updateTask(parentTask)
        }
    }

    /// 当子任务标记未完成时更新父任务
    func updateParentOnSubtaskIncomplete(childTaskId: String) async throws {
        // 获取子任务
        let childDoc = try await db.collection("tasks").document(childTaskId).getDocument()
        guard let childTask = try? childDoc.data(as: Task.self),
              let parentId = childTask.parentTaskId else { return }

        // 获取父任务
        let parentDoc = try await db.collection("tasks").document(parentId).getDocument()
        guard var parentTask = try? parentDoc.data(as: Task.self) else { return }

        // 如果父任务已完成，标记为未完成
        if parentTask.isDone {
            parentTask.isDone = false
            parentTask.doneAt = nil
            try await taskService.updateTask(parentTask)
        }
    }

    // MARK: - Milestone Management

    /// 创建里程碑任务
    func createMilestone(_ task: Task) async throws {
        var milestone = task
        milestone.isMilestone = true
        milestone.createdAt = Date()
        milestone.updatedAt = Date()

        _ = try await taskService.createTask(milestone)
    }

    /// 获取项目的所有里程碑
    func fetchMilestones(userId: String, projectCategory: TaskCategory?) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        var query: Query = db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isMilestone", isEqualTo: true)
            .whereField("isDone", isEqualTo: false)

        if let category = projectCategory {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }

        query.order(by: "deadlineAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let milestones = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                subject.send(milestones)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Bulk Operations

    /// 完成所有子任务
    func completeAllSubtasks(parentTaskId: String) async throws {
        let snapshot = try await db.collection("tasks")
            .whereField("parentTaskId", isEqualTo: parentTaskId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()

        for document in snapshot.documents {
            let ref = document.reference
            batch.updateData([
                "isDone": true,
                "doneAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: ref)
        }

        try await batch.commit()
    }

    /// 重置所有子任务为未完成
    func resetAllSubtasks(parentTaskId: String) async throws {
        let snapshot = try await db.collection("tasks")
            .whereField("parentTaskId", isEqualTo: parentTaskId)
            .whereField("isDone", isEqualTo: true)
            .getDocuments()

        let batch = db.batch()

        for document in snapshot.documents {
            let ref = document.reference
            batch.updateData([
                "isDone": false,
                "doneAt": NSNull(),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: ref)
        }

        try await batch.commit()
    }
}
