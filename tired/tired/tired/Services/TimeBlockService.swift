import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 时间块服务
class TimeBlockService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Time Blocks

    /// 获取用户的所有时间块（实时监听）
    func fetchTimeBlocks(userId: String) -> AnyPublisher<[TimeBlock], Error> {
        let subject = PassthroughSubject<[TimeBlock], Error>()

        db.collection("timeBlocks")
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

                let blocks = documents.compactMap { doc -> TimeBlock? in
                    try? doc.data(as: TimeBlock.self)
                }

                subject.send(blocks)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取特定日期的时间块
    func fetchTimeBlocksForDate(userId: String, date: Date) async throws -> [TimeBlock] {
        let snapshot = try await db.collection("timeBlocks")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let allBlocks = snapshot.documents.compactMap { doc -> TimeBlock? in
            try? doc.data(as: TimeBlock.self)
        }

        // 过滤出在该日期有效的时间块
        return allBlocks.filter { $0.isActiveOn(date) }
    }

    // MARK: - Create/Update/Delete Time Blocks

    /// 创建时间块
    func createTimeBlock(_ timeBlock: TimeBlock) async throws {
        var newBlock = timeBlock
        newBlock.createdAt = Date()
        newBlock.updatedAt = Date()

        _ = try await db.collection("timeBlocks").addDocument(from: newBlock)
    }

    /// 更新时间块
    func updateTimeBlock(_ timeBlock: TimeBlock) async throws {
        guard let id = timeBlock.id else {
            throw NSError(domain: "TimeBlockService", code: -1, userInfo: [NSLocalizedDescriptionKey: "TimeBlock ID is missing"])
        }

        var updatedBlock = timeBlock
        updatedBlock.updatedAt = Date()

        try await db.collection("timeBlocks").document(id).setData(from: updatedBlock)
    }

    /// 删除时间块
    func deleteTimeBlock(id: String) async throws {
        try await db.collection("timeBlocks").document(id).delete()
    }

    // MARK: - Time Block Analysis

    /// 计算特定日期的可用时间段（考虑时间块）
    func computeAvailableTimeSlots(
        for date: Date,
        timeBlocks: [TimeBlock]
    ) -> [TimeSlot] {
        // 从 00:00 到 23:59 开始
        var availableSlots = [TimeSlot(start: TimeOfDay(hour: 0, minute: 0), end: TimeOfDay(hour: 23, minute: 59))]

        // 获取这一天的所有时间块
        let dayBlocks = timeBlocks.filter { $0.isActiveOn(date) }

        // 减去硬阻止的时间块
        for block in dayBlocks where block.blockType == .hard {
            var newAvailableSlots: [TimeSlot] = []
            for slot in availableSlots {
                newAvailableSlots.append(contentsOf: slot.subtracting(block))
            }
            availableSlots = newAvailableSlots
        }

        return availableSlots
    }

    /// 检查任务是否可以排在给定时间
    func canScheduleTaskAt(
        date: Date,
        startTime: TimeOfDay,
        durationMinutes: Int,
        timeBlocks: [TimeBlock]
    ) -> (canSchedule: Bool, reason: String?) {
        let dayBlocks = timeBlocks.filter { $0.isActiveOn(date) }

        let endMinutes = startTime.totalMinutes + durationMinutes
        let endTime = TimeOfDay(hour: endMinutes / 60, minute: endMinutes % 60)

        // 检查是否与硬阻止的时间块冲突
        for block in dayBlocks where block.blockType == .hard {
            // 检查任务时间段是否与时间块重叠
            if !(endTime <= block.startTime || startTime >= block.endTime) {
                return (false, "此时间段已被\(block.title)保留（硬阻止）")
            }
        }

        return (true, nil)
    }

    /// 获取一周内被硬阻止的时间总长度
    func getBlockedMinutesInWeek(
        userId: String,
        weekStart: Date,
        timeBlocks: [TimeBlock]
    ) -> Int {
        let calendar = Calendar.current
        var totalBlockedMinutes = 0

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }

            let dayBlocks = timeBlocks.filter { $0.isActiveOn(date) }
            for block in dayBlocks where block.blockType == .hard {
                totalBlockedMinutes += block.durationMinutes
            }
        }

        return totalBlockedMinutes
    }

    // MARK: - Smart Scheduling

    /// 在考虑时间块的前提下进行自动排程
    /// 返回排程的任务和无法排程的任务
    func autoPlanWithTimeBlocks(
        tasks: [Task],
        options: AutoPlanService.AutoPlanOptions,
        timeBlocks: [TimeBlock]
    ) -> (scheduled: [Task], unscheduled: [Task]) {
        var scheduled: [Task] = []
        var unscheduled: [Task] = []

        let calendar = Calendar.current

        for task in tasks where task.plannedDate == nil && !task.isDone && !task.isDateLocked {
            var taskScheduled = false

            // 尝试在这一周的每一天排程任务
            for dayOffset in 0..<7 {
                guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: options.weekStart) else {
                    continue
                }

                // 获取这一天的可用时间段
                let availableSlots = computeAvailableTimeSlots(for: dayDate, timeBlocks: timeBlocks)

                // 检查是否有足够的可用时间
                let totalAvailableMinutes = availableSlots.reduce(0) { sum, slot in
                    sum + (slot.endTime.totalMinutes - slot.startTime.totalMinutes)
                }

                let taskDuration = task.estimatedMinutes ?? 60

                if totalAvailableMinutes >= taskDuration {
                    var updatedTask = task
                    updatedTask.plannedDate = dayDate
                    scheduled.append(updatedTask)
                    taskScheduled = true
                    break
                }
            }

            if !taskScheduled {
                unscheduled.append(task)
            }
        }

        return (scheduled, unscheduled)
    }

    // MARK: - Suggestions and Analytics

    /// 获取优化时间管理的建议
    func getTimeManagementSuggestions(
        userId: String,
        timeBlocks: [TimeBlock],
        weekStart: Date
    ) -> [String] {
        var suggestions: [String] = []

        let blockedMinutes = getBlockedMinutesInWeek(userId: userId, weekStart: weekStart, timeBlocks: timeBlocks)
        let totalMinutes = 7 * 24 * 60
        let blockedPercentage = (blockedMinutes * 100) / totalMinutes

        if blockedPercentage > 60 {
            suggestions.append("⚠️ 您已预留超过 60% 的时间，可用于排程任务的时间较少")
        } else if blockedPercentage < 10 {
            suggestions.append("💡 您可以考虑预留更多的深度工作时间或休息时间")
        }

        // 检查是否有充分的深度工作时间块
        let focusBlocks = timeBlocks.filter { $0.title.lowercased().contains("work") || $0.title.lowercased().contains("focus") }
        if focusBlocks.isEmpty {
            suggestions.append("💡 建议创建\"深度工作\"时间块来保护专注时间")
        }

        // 检查是否有足够的休息时间
        let breakBlocks = timeBlocks.filter { $0.title.lowercased().contains("break") || $0.title.lowercased().contains("lunch") }
        if breakBlocks.isEmpty {
            suggestions.append("💡 建议创建\"午餐\"或\"休息\"时间块来保证充分休息")
        }

        return suggestions
    }
}
