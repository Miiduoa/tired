import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 任务服务 - 核心业务逻辑
class TaskService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Tasks

    /// 获取用户的所有未完成任务
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

    /// 获取今天的任务
    func fetchTodayTasks(userId: String) -> AnyPublisher<[Task], Error> {
        fetchActiveTasks(userId: userId)
            .map { tasks in
                let calendar = Calendar.current
                let today = Date()

                return tasks.filter { task in
                    // 有plannedDate且是今天
                    if let planned = task.plannedDate,
                       calendar.isDate(planned, equalTo: today, toGranularity: .day) {
                        return true
                    }

                    // 没有plannedDate但deadline是今天
                    if task.plannedDate == nil,
                       let deadline = task.deadlineAt,
                       calendar.isDate(deadline, equalTo: today, toGranularity: .day) {
                        return true
                    }

                    return false
                }
            }
            .eraseToAnyPublisher()
    }

    /// 获取本周的任务
    func fetchWeekTasks(userId: String) -> AnyPublisher<[Task], Error> {
        fetchActiveTasks(userId: userId)
            .map { tasks in
                let calendar = Calendar.current
                let today = Date()

                return tasks.filter { task in
                    guard let planned = task.plannedDate else { return false }
                    return calendar.isDate(planned, equalTo: today, toGranularity: .weekOfYear)
                }
            }
            .eraseToAnyPublisher()
    }

    /// 获取未排程的任务（Backlog）
    func fetchBacklogTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isDone", isEqualTo: false)
            .whereField("plannedDate", isEqualTo: NSNull())
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

                // 按deadline排序
                let sorted = tasks.sorted { t1, t2 in
                    if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                        return d1 < d2
                    }
                    if t1.deadlineAt != nil { return true }
                    if t2.deadlineAt != nil { return false }
                    return t1.createdAt < t2.createdAt
                }

                subject.send(sorted)
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
