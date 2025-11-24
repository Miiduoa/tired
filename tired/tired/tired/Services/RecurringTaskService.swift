import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 周期性任务服务
class RecurringTaskService: ObservableObject {
    private let db = FirebaseManager.shared.db
    private let taskService = TaskService()

    // MARK: - Fetch Recurring Tasks

    /// 获取用户的所有周期任务（实时监听）
    func fetchRecurringTasks(userId: String) -> AnyPublisher<[RecurringTask], Error> {
        let subject = PassthroughSubject<[RecurringTask], Error>()

        db.collection("recurringTasks")
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

                let recurringTasks = documents.compactMap { doc -> RecurringTask? in
                    try? doc.data(as: RecurringTask.self)
                }

                subject.send(recurringTasks)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取单个周期任务
    func fetchRecurringTask(id: String) async throws -> RecurringTask {
        let doc = try await db.collection("recurringTasks").document(id).getDocument()
        guard let recurringTask = try? doc.data(as: RecurringTask.self) else {
            throw NSError(domain: "RecurringTaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recurring task not found"])
        }
        return recurringTask
    }

    // MARK: - Create/Update Recurring Tasks

    /// 创建周期任务
    func createRecurringTask(_ recurringTask: RecurringTask) async throws {
        var newTask = recurringTask
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        newTask.nextGenerationDate = recurringTask.startDate

        _ = try await db.collection("recurringTasks").addDocument(from: newTask)

        // 立即生成第一批实例
        try await generateDueInstances()
    }

    /// 更新周期任务
    func updateRecurringTask(_ recurringTask: RecurringTask) async throws {
        guard let id = recurringTask.id else {
            throw NSError(domain: "RecurringTaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recurring task ID is missing"])
        }

        var updatedTask = recurringTask
        updatedTask.updatedAt = Date()

        try await db.collection("recurringTasks").document(id).setData(from: updatedTask)
    }

    /// 删除周期任务（同时删除已生成的实例）
    func deleteRecurringTask(id: String) async throws {
        let recurringTask = try await fetchRecurringTask(id: id)

        // 删除已生成的任务实例
        let batch = db.batch()
        for instanceId in recurringTask.generatedInstanceIds {
            let ref = db.collection("tasks").document(instanceId)
            batch.deleteDocument(ref)
        }

        // 删除周期任务本身
        let recurringRef = db.collection("recurringTasks").document(id)
        batch.deleteDocument(recurringRef)

        try await batch.commit()
    }

    // MARK: - Instance Generation

    /// 生成应该生成的任务实例（每天运行一次，通常在晚上）
    func generateDueInstances() async throws {
        let now = Date()
        let calendar = Calendar.current

        // 获取所有有效的周期任务（没有结束或还没到结束日期）
        let snapshot = try await db.collection("recurringTasks")
            .getDocuments()

        for document in snapshot.documents {
            guard var recurringTask = try? document.data(as: RecurringTask.self) else { continue }

            // 检查是否应该生成实例 (Safely unwrap endDate)
            let isPastEndDate = recurringTask.endDate.map { $0 <= now } ?? false
            let shouldGenerate = recurringTask.nextGenerationDate <= now && !isPastEndDate

            if shouldGenerate {
                try await generateInstancesForRecurringTask(&recurringTask)
            }
        }
    }

    /// 为特定周期任务生成实例
    private func generateInstancesForRecurringTask(_ recurringTask: inout RecurringTask) async throws {
        let calendar = Calendar.current
        let now = Date()

        // 计算生成范围：从 nextGenerationDate 到 30 天后
        guard let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now),
              let thirtyDaysFromNextGen = calendar.date(byAdding: .day, value: 30, to: recurringTask.nextGenerationDate) else {
            print("❌ Error: Could not calculate date range for instance generation.")
            return
        }

        let endDate = min(
            recurringTask.endDate ?? thirtyDaysFromNow,
            thirtyDaysFromNextGen
        )

        // 计算这个时间段内的所有匹配日期
        let occurrences = computeOccurrences(
            startDate: recurringTask.nextGenerationDate,
            endDate: endDate,
            rule: recurringTask.recurrenceRule,
            skipDates: recurringTask.skipDates
        )

        // 为每个日期创建任务实例
        var newInstanceIds: [String] = []
        let batch = db.batch()

        for occurrence in occurrences {
            let taskRef = db.collection("tasks").document()
            let newTaskInstance = Task(
                id: taskRef.documentID,
                userId: recurringTask.userId,
                title: recurringTask.title,
                description: recurringTask.description,
                category: recurringTask.category,
                priority: recurringTask.priority,
                deadlineAt: occurrence,
                estimatedMinutes: recurringTask.estimatedMinutes,
                sourceType: .manual,
                createdAt: Date(),
                updatedAt: Date()
            )

            try batch.setData(from: newTaskInstance, forDocument: taskRef)
            newInstanceIds.append(taskRef.documentID)
        }

        // 更新周期任务的生成记录
        guard let nextGenDate = calendar.date(byAdding: .day, value: 30, to: endDate) else {
            print("❌ Error: Could not calculate next generation date.")
            return
        }
        
        recurringTask.generatedInstanceIds.append(contentsOf: newInstanceIds)
        recurringTask.lastGeneratedDate = now
        recurringTask.nextGenerationDate = nextGenDate
        recurringTask.updatedAt = Date()

        // 提交批量操作
        try await batch.commit()

        // 保存更新的周期任务
        try await updateRecurringTask(recurringTask)
    }

    // MARK: - Occurrence Management

    /// 跳过某个周期任务的某次发生
    func skipOccurrence(date: Date, recurringTaskId: String) async throws {
        guard var recurringTask = try? await fetchRecurringTask(id: recurringTaskId) else { return }

        // 检查这个日期是否已经在跳过列表中
        let calendar = Calendar.current
        if !recurringTask.skipDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            recurringTask.skipDates.append(date)
            try await updateRecurringTask(recurringTask)

            // 同时删除这个日期生成的任务实例（如果存在）
            try await deleteInstanceForDate(date, recurringTaskId: recurringTaskId)
        }
    }

    /// 取消跳过某个日期
    func unskipOccurrence(date: Date, recurringTaskId: String) async throws {
        guard var recurringTask = try? await fetchRecurringTask(id: recurringTaskId) else { return }

        let calendar = Calendar.current
        recurringTask.skipDates.removeAll { calendar.isDate($0, inSameDayAs: date) }

        try await updateRecurringTask(recurringTask)

        // 重新生成这个日期的任务实例
        try await generateInstanceForDate(date, from: recurringTask)
    }

    // MARK: - Private Helper Methods

    /// 计算重复规则匹配的日期
    private func computeOccurrences(
        startDate: Date,
        endDate: Date,
        rule: RecurrenceRule,
        skipDates: [Date]
    ) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            // 检查是否匹配规则
            if matchesRule(currentDate, rule: rule) {
                // 检查是否在跳过列表中
                let isSkipped = skipDates.contains { calendar.isDate($0, inSameDayAs: currentDate) }

                if !isSkipped {
                    occurrences.append(currentDate)
                }
            }

            // 移到下一天
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }

        return occurrences
    }

    /// 检查日期是否匹配重复规则
    private func matchesRule(_ date: Date, rule: RecurrenceRule) -> Bool {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)  // 1=周日, 2=周一, ..., 7=周六

        // 转换为我们使用的格式 (1=周一, 7=周日)
        let normalizedDayOfWeek = dayOfWeek == 1 ? 7 : dayOfWeek - 1

        switch rule {
        case .daily:
            return true

        case .weekdays:
            return (1...5).contains(normalizedDayOfWeek)  // 周一-周五

        case .weekends:
            return normalizedDayOfWeek == 6 || normalizedDayOfWeek == 7  // 周六-周日

        case .weekly(let targetDayOfWeek):
            return normalizedDayOfWeek == targetDayOfWeek

        case .biweekly(let targetDayOfWeek):
            // 这里需要额外的逻辑来跟踪两周周期
            // 简化版：仅检查是否是目标日期（完整实现需要起始日期）
            return normalizedDayOfWeek == targetDayOfWeek

        case .monthly(let targetDayOfMonth):
            return calendar.component(.day, from: date) == targetDayOfMonth

        case .custom(let daysOfWeek):
            return daysOfWeek.contains(normalizedDayOfWeek)
        }
    }

    /// 为特定日期删除任务实例
    private func deleteInstanceForDate(_ date: Date, recurringTaskId: String) async throws {
        guard let recurringTask = try? await fetchRecurringTask(id: recurringTaskId) else { return }

        let calendar = Calendar.current

        // 找到对应日期的任务实例
        for instanceId in recurringTask.generatedInstanceIds {
            let taskRef = db.collection("tasks").document(instanceId)
            let taskDoc = try await taskRef.getDocument()

            guard let task = try? taskDoc.data(as: Task.self),
                  let deadlineAt = task.deadlineAt,
                  calendar.isDate(deadlineAt, inSameDayAs: date) else {
                continue
            }

            // 删除这个实例
            try await taskService.deleteTask(id: instanceId)

            // 更新周期任务的实例列表
            var updatedTask = recurringTask
            updatedTask.generatedInstanceIds.removeAll { $0 == instanceId }
            try await updateRecurringTask(updatedTask)
        }
    }

    /// 为特定日期生成任务实例
    private func generateInstanceForDate(_ date: Date, from recurringTask: RecurringTask) async throws {
        let taskRef = db.collection("tasks").document()

        var newTask = Task(
            id: taskRef.documentID,
            userId: recurringTask.userId,
            title: recurringTask.title,
            description: recurringTask.description,
            category: recurringTask.category,
            priority: recurringTask.priority,
            deadlineAt: date,
            estimatedMinutes: recurringTask.estimatedMinutes,
            sourceType: .manual,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await taskService.createTask(newTask)

        // 更新周期任务的实例列表
        var updatedRecurringTask = recurringTask
        updatedRecurringTask.generatedInstanceIds.append(taskRef.documentID)
        try await updateRecurringTask(updatedRecurringTask)
    }
}
