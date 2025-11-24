import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

enum PlannedDateFilter {
    case today
    case thisWeek
    case backlog
    case none // No specific planned date filter
}

/// 任務服務 - 核心業務邏輯
class TaskService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Tasks (Paginated)

    /// 獲取任務 - 分頁版本
    func fetchTasksPaginated(
        userId: String,
        isDone: Bool,
        limit: Int,
        lastDocumentSnapshot: DocumentSnapshot?,
        plannedDateFilter: PlannedDateFilter
    ) async throws -> (tasks: [Task], lastDocumentSnapshot: DocumentSnapshot?) {
        var query: Query = db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isDone", isEqualTo: isDone)

        switch plannedDateFilter {
        case .today:
            // For today's tasks, we need to query for plannedDate today or deadlineAt today if plannedDate is null
            // This is complex with Firestore's limitations on OR queries.
            // A more robust solution might involve:
            // 1. Fetching all active tasks and filtering client-side (less efficient for large datasets)
            // 2. Using a backend function (Firebase Function) to pre-process/index tasks for "today"
            // For now, we will fetch active tasks and filter client-side for "today" and "thisWeek" filters.
            // So, for .today and .thisWeek, we'll fetch all active and filter later in ViewModel.
            // This paginated method will mainly be used for backlog for now.
            query = query.whereField("plannedDate", isGreaterThanOrEqualTo: Calendar.current.startOfDay(for: Date()))
                .whereField("plannedDate", isLessThan: Calendar.current.startOfDay(for: Date().addingTimeInterval(24*60*60)))
            
        case .thisWeek:
            // Similar complexity as .today for pure Firestore query.
            // Fetch active tasks and filter client-side.
            guard let startOfWeek = Date().startOfWeek(),
                  let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) else {
                return ([], nil)
            }
            query = query.whereField("plannedDate", isGreaterThanOrEqualTo: startOfWeek)
                .whereField("plannedDate", isLessThan: endOfWeek)

        case .backlog:
            query = query.whereField("plannedDate", isEqualTo: NSNull())
        case .none:
            break // No specific planned date filter
        }
        
        query = query.order(by: "createdAt", descending: true) // Default order

        if let lastSnapshot = lastDocumentSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }
        
        query = query.limit(to: limit)

        let snapshot = try await query.getDocuments()
        let tasks = snapshot.documents.compactMap { doc -> Task? in
            try? doc.data(as: Task.self)
        }

        return (tasks, snapshot.documents.last)
    }

    /// 獲取所有活躍任務（非分頁，用於 client-side 過濾 Today/Week）
    func fetchActiveTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isDone", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let tasks = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                subject.send(tasks)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    /// 创建新任务
    func createTask(_ task: Task) async throws {
        var newTask = task
        newTask.createdAt = Date()
        newTask.updatedAt = Date()

        _ = try db.collection("tasks").addDocument(from: newTask)
    }

    /// 更新任务
    func updateTask(_ task: Task) async throws {
        guard let id = task.id else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task ID is missing"])
        }

        var updatedTask = task
        updatedTask.updatedAt = Date()

        try db.collection("tasks").document(id).setData(from: updatedTask)
    }

    /// 删除任务
    func deleteTask(id: String) async throws {
        try await db.collection("tasks").document(id).delete()
    }

    /// 标记任务完成/未完成
    func toggleTaskDone(id: String, isDone: Bool) async throws {
        let updates: [String: Any] = [
            "isDone": isDone,
            "doneAt": isDone ? Timestamp(date: Date()) : NSNull(),
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("tasks").document(id).updateData(updates)
    }

    /// 更新任务排程日期
    func updatePlannedDate(taskId: String, plannedDate: Date?, isLocked: Bool) async throws {
        let updates: [String: Any] = [
            "plannedDate": plannedDate != nil ? Timestamp(date: plannedDate!) : NSNull(),
            "isDateLocked": isLocked,
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("tasks").document(taskId).updateData(updates)
    }

    // MARK: - Batch Operations

    /// 批量更新任务（用于autoplan）
    func batchUpdateTasks(_ tasks: [Task]) async throws {
        let batch = db.batch()

        for task in tasks {
            guard let id = task.id else { continue }

            var updatedTask = task
            updatedTask.updatedAt = Date()

            let ref = db.collection("tasks").document(id)
            try batch.setData(from: updatedTask, forDocument: ref)
        }

        try await batch.commit()
    }
}
