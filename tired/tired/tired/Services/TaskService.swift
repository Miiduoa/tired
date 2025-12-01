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

    // MARK: - Real-time Listeners for Today/Week/Backlog

    /// 獲取今天的任務（實時監聽）
    func fetchTodayTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        let listener = db.collection("tasks")
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

                let calendar = Calendar.current
                let startOfToday = calendar.startOfDay(for: Date())
                let tasks = documents
                    .compactMap { doc -> Task? in
                        try? doc.data(as: Task.self)
                    }
                    .filter { task in
                        // 今日或逾期的任務（包含僅有 deadline 而無 plannedDate 的情況）
                        if task.isOverdue { return true }
                        if task.isTaskForToday { return true }

                        // 額外保險：若 plannedDate 在今天
                        if let planned = task.plannedDate,
                           calendar.isDate(planned, inSameDayAs: startOfToday) {
                            return true
                        }
                        // 若 deadline 在今天
                        if let deadline = task.deadlineAt,
                           calendar.isDate(deadline, inSameDayAs: startOfToday) {
                            return true
                        }
                        return false
                    }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// 獲取本週的任務（實時監聽）
    func fetchWeekTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

        let listener = db.collection("tasks")
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
                }.filter { task in
                    // 本週的任務：plannedDate 在本週範圍內，或無排程但 deadline 在本週
                    if let planned = task.plannedDate {
                        return planned >= weekStart && planned < weekEnd
                    }
                    if let deadline = task.deadlineAt {
                        return deadline >= weekStart && deadline < weekEnd
                    }
                    return false
                }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// 獲取未排程的任務（Backlog，實時監聽）
    func fetchBacklogTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        let listener = db.collection("tasks")
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
                }.filter { task in
                    // Backlog：沒有 plannedDate 的任務
                    return task.plannedDate == nil
                }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// 搜尋任務（根據關鍵字）
    func searchTasks(userId: String, keyword: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()
        let lowercasedKeyword = keyword.lowercased()

        let listener = db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
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
                }.filter { task in
                    task.title.lowercased().contains(lowercasedKeyword) ||
                    (task.description?.lowercased().contains(lowercasedKeyword) ?? false)
                }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// 獲取已過期的任務
    func fetchOverdueTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()
        let now = Date()

        let listener = db.collection("tasks")
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
                }.filter { task in
                    if let deadline = task.deadlineAt {
                        return deadline < now
                    }
                    return false
                }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// 獲取所有任務（包括已完成）
    func fetchAllTasks(userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        let listener = db.collection("tasks")
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

                let tasks = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCompletion: { _ in listener.remove() }, receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

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
            let startOfWeek = Date.startOfWeek()
            guard let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) else {
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

    /// 根據ID獲取單個任務
    func fetchTask(id: String) async throws -> Task? {
        let document = try await db.collection("tasks").document(id).getDocument()
        return try? document.data(as: Task.self)
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
    
    /// 獲取單個任務
    func fetchTask(id: String) async throws -> Task {
        let snapshot = try await db.collection("tasks").document(id).getDocument()
        guard let task = try? snapshot.data(as: Task.self) else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
        return task
    }

    // MARK: - CRUD Operations

    /// 创建新任务
    func createTask(_ task: Task) async throws -> Task {
        var newTask = task
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        
        // 自動計算 isToday 欄位
        newTask.isToday = computeIsToday(for: newTask)

        let ref = try db.collection("tasks").addDocument(from: newTask)
        newTask.id = ref.documentID
        
        // Schedule notification
        NotificationService.shared.scheduleNotification(for: newTask)
        
        return newTask
    }

    /// 更新任务
    func updateTask(_ task: Task) async throws {
        guard let id = task.id else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task ID is missing"])
        }

        var updatedTask = task
        updatedTask.updatedAt = Date()
        
        // 自動計算 isToday 欄位
        updatedTask.isToday = computeIsToday(for: updatedTask)

        try db.collection("tasks").document(id).setData(from: updatedTask)
        
        // Reschedule notification
        NotificationService.shared.scheduleNotification(for: updatedTask)
    }
    
    /// 計算任務是否屬於「今天」
    private func computeIsToday(for task: Task) -> Bool {
        let calendar = Calendar.current
        
        // 如果已完成，不算今天的任務
        if task.isDone { return false }
        
        // 優先檢查 plannedDate
        if let plannedDate = task.plannedDate {
            return calendar.isDateInToday(plannedDate)
        }
        
        // 如果沒有 plannedDate 但有 deadlineAt，且 deadline 是今天
        if let deadline = task.deadlineAt {
            return calendar.isDateInToday(deadline)
        }
        
        return false
    }

    /// 删除任务
    func deleteTask(id: String) async throws {
        // Cancel notification before deleting
        NotificationService.shared.cancelNotification(withIdentifier: "task-\(id)")
        try await db.collection("tasks").document(id).delete()
    }

    /// 标记任务完成/未完成
    func toggleTaskDone(id: String, isDone: Bool) async throws {
        if isDone {
            // Cancel notification if task is being marked as done
            NotificationService.shared.cancelNotification(withIdentifier: "task-\(id)")
        }

        let updates: [String: Any] = [
            "isDone": isDone,
            "doneAt": isDone ? Timestamp(date: Date()) : NSNull(),
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("tasks").document(id).updateData(updates)

        // Moodle-like 功能：作業提交後通知教師
        if isDone {
            let task = try await getTask(id: id)
            if task.taskType == .homework {
                await sendHomeworkSubmissionNotification(task: task)
            }
        }
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

    // MARK: - Task Completion Processing ✅ 新增：完善的任务完成流程

    /// 完成任务并触发后续处理（激励反馈、统计更新等）
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - userId: 用户 ID
    /// - Returns: 完成后的任务对象和任何的成就解锁
    func completeTask(taskId: String, userId: String) async throws -> (task: Task, achievement: TaskAchievement?) {
        // 1. 获取任务
        let taskDoc = try await db.collection("tasks").document(taskId).getDocument()
        guard var task = try? taskDoc.data(as: Task.self) else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }

        // 2. 标记完成
        task.isDone = true
        task.doneAt = Date()
        task.updatedAt = Date()

        // 3. 保存更新
        try await updateTask(task)

        // 4. 更新用户统计
        try await updateUserCompletionStats(userId: userId, task: task)

        // 5. 检查成就解锁 ✅ 激励系统
        let achievement = try await checkAndAwardAchievements(userId: userId, completedTask: task)

        return (task, achievement)
    }

    /// 更新用户的任务完成统计
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - task: 完成的任务
    private func updateUserCompletionStats(userId: String, task: Task) async throws {
        let userRef = db.collection("users").document(userId)

        // 原子性更新：增加完成任务计数、更新最后完成时间
        try await userRef.updateData([
            "completedTaskCount": FieldValue.increment(Int64(1)),
            "lastTaskCompletedAt": Timestamp(date: task.doneAt ?? Date()),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 检查并授予成就
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - completedTask: 刚完成的任务
    /// - Returns: 新解锁的成就，如果没有则为 nil
    private func checkAndAwardAchievements(userId: String, completedTask: Task) async throws -> TaskAchievement? {
        // 获取用户当前统计
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else { return nil }

        let completedCount = userData["completedTaskCount"] as? Int ?? 1

        // 检查成就里程碑
        let achievement: TaskAchievement?

        switch completedCount {
        case 1:
            achievement = TaskAchievement(
                id: UUID().uuidString,
                type: .firstTaskCompleted,
                title: "初出茅庐",
                description: "完成第一个任务",
                icon: "🌱",
                earnedAt: Date()
            )

        case 5:
            achievement = TaskAchievement(
                id: UUID().uuidString,
                type: .fiveTasksCompleted,
                title: "小有成就",
                description: "完成 5 个任务",
                icon: "⭐",
                earnedAt: Date()
            )

        case 10:
            achievement = TaskAchievement(
                id: UUID().uuidString,
                type: .tenTasksCompleted,
                title: "任务大师",
                description: "完成 10 个任务",
                icon: "🎯",
                earnedAt: Date()
            )

        case 50:
            achievement = TaskAchievement(
                id: UUID().uuidString,
                type: .fiftyTasksCompleted,
                title: "生产力达人",
                description: "完成 50 个任务",
                icon: "🚀",
                earnedAt: Date()
            )

        case 100:
            achievement = TaskAchievement(
                id: UUID().uuidString,
                type: .hundredTasksCompleted,
                title: "传奇任务者",
                description: "完成 100 个任务",
                icon: "👑",
                earnedAt: Date()
            )

        default:
            achievement = nil
        }

        // 保存成就
        if let achievement = achievement, let achievementId = achievement.id {
            try db.collection("userAchievements").document(achievementId).setData(from: achievement)
        }

        return achievement
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
    
    /// 還原已刪除的任務（保持原 ID）
    func restoreTask(_ task: Task) async throws {
        guard let id = task.id else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task ID is missing for restore"])
        }
        
        // 使用 setData 來指定 ID 寫入
        try db.collection("tasks").document(id).setData(from: task)
        
        // 重新排程通知
        NotificationService.shared.scheduleNotification(for: task)
    }

    // MARK: - Notification Integration (Moodle-like)

    /// 發送作業提交通知給教師
    private func sendHomeworkSubmissionNotification(task: Task) async {
        do {
            // 獲取學生姓名
            guard let studentId = task.userId else { return }
            let userDoc = try await db.collection("users")
                .document(studentId)
                .getDocument()
            let studentName = userDoc.data()?["displayName"] as? String ?? "學生"

            // 獲取組織名稱（如果有）
            var organizationName = "課程"
            if let orgId = task.organizationId {
                let orgDoc = try await db.collection("organizations")
                    .document(orgId)
                    .getDocument()
                organizationName = orgDoc.data()?["name"] as? String ?? "課程"
            }

            // 發送通知
            NotificationService.shared.notifyTeacherOfSubmission(
                studentName: studentName,
                assignmentTitle: task.title,
                organizationName: organizationName
            )

            print("✅ Homework submission notification sent for: \(task.title)")
        } catch {
            print("❌ Error sending submission notification: \(error)")
        }
    }
}
