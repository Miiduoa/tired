import Foundation

/// 輕量 Undo 系統 - 只支援最近一次操作的 10 秒內復原
class UndoService: ObservableObject {
    static let shared = UndoService()

    private let storageKey = "last_undoable_action"
    private let undoTimeout: TimeInterval = 10.0

    private init() {}

    struct UndoRecord: Codable {
        let type: String
        let taskIds: [String]
        let before: [String: TaskSnapshot]
        let timestamp: Date

        struct TaskSnapshot: Codable {
            let state: String
            let doneAt: Date?
            let skippedAt: Date?
            let plannedWorkDate: Date?
            let committedWeekStartDate: Date?
            let isTodayFocus: Bool
            let isDateLocked: Bool
        }
    }

    /// 為任務創建快照
    func snapshotTask(_ task: Task) -> UndoRecord.TaskSnapshot {
        return UndoRecord.TaskSnapshot(
            state: task.state.rawValue,
            doneAt: task.doneAt,
            skippedAt: task.skippedAt,
            plannedWorkDate: task.plannedWorkDate,
            committedWeekStartDate: task.committedWeekStartDate,
            isTodayFocus: task.isTodayFocus,
            isDateLocked: task.isDateLocked
        )
    }

    /// 記錄可撤銷的操作
    func recordAction(type: String, tasks: [Task]) {
        var beforeState: [String: UndoRecord.TaskSnapshot] = [:]
        for task in tasks {
            beforeState[task.id] = snapshotTask(task)
        }

        let record = UndoRecord(
            type: type,
            taskIds: tasks.map { $0.id },
            before: beforeState,
            timestamp: Date()
        )

        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 撤銷最後一次操作
    func undoLastAction(tasksById: [String: Task], onUpdate: @escaping (Task) -> Void) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let record = try? JSONDecoder().decode(UndoRecord.self, from: data) else {
            return false
        }

        // 檢查是否超時
        if Date().timeIntervalSince(record.timestamp) > undoTimeout {
            clearUndoRecord()
            return false
        }

        // 恢復每個任務的狀態
        for taskId in record.taskIds {
            guard var task = tasksById[taskId],
                  let snapshot = record.before[taskId] else {
                continue
            }

            task.state = Task.TaskState(rawValue: snapshot.state) ?? .open
            task.doneAt = snapshot.doneAt
            task.skippedAt = snapshot.skippedAt
            task.plannedWorkDate = snapshot.plannedWorkDate
            task.committedWeekStartDate = snapshot.committedWeekStartDate
            task.isTodayFocus = snapshot.isTodayFocus
            task.isDateLocked = snapshot.isDateLocked
            task.updatedAt = Date()

            onUpdate(task)
        }

        clearUndoRecord()
        return true
    }

    /// 清除 undo 記錄
    func clearUndoRecord() {
        UserDefaults.standard.removeItem(forKey: storageKey)
    }

    /// 檢查是否有可撤銷的操作
    func hasUndoableAction() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let record = try? JSONDecoder().decode(UndoRecord.self, from: data) else {
            return false
        }

        return Date().timeIntervalSince(record.timestamp) <= undoTimeout
    }
}
