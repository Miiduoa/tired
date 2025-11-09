import Foundation

// MARK: - Undo Action
struct UndoAction: Codable {
    var type: ActionType
    var taskIds: [String]
    var before: [String: TaskSnapshot]
    var timestamp: Date

    enum ActionType: String, Codable {
        case complete
        case skip
        case batchPostpone
        case batchComplete
        case batchSkip
    }
}

// MARK: - Task Snapshot
struct TaskSnapshot: Codable {
    var state: String
    var doneAt: Date?
    var skippedAt: Date?
    var plannedWorkDate: Date?
    var committedWeekStartDate: Date?
    var isTodayFocus: Bool
    var isDateLocked: Bool
}

// MARK: - Undo Service
@MainActor
class UndoService {

    static let shared = UndoService()

    private let STORAGE_KEY = "last_undoable_action"
    private let UNDO_TIMEOUT_SECONDS: TimeInterval = 10

    private init() {}

    // MARK: - Record Action

    func recordAction(
        type: UndoAction.ActionType,
        tasks: [Task]
    ) {
        var before: [String: TaskSnapshot] = [:]

        for task in tasks {
            before[task.id] = snapshotTask(task)
        }

        let action = UndoAction(
            type: type,
            taskIds: tasks.map { $0.id },
            before: before,
            timestamp: Date()
        )

        if let encoded = try? JSONEncoder().encode(action) {
            UserDefaults.standard.set(encoded, forKey: STORAGE_KEY)
        }
    }

    // MARK: - Undo

    func undoLastAction(taskService: TaskService) async -> Bool {
        guard let data = UserDefaults.standard.data(forKey: STORAGE_KEY),
              let action = try? JSONDecoder().decode(UndoAction.self, from: data) else {
            return false
        }

        // Check timeout
        let elapsed = Date().timeIntervalSince(action.timestamp)
        if elapsed > UNDO_TIMEOUT_SECONDS {
            clearUndo()
            return false
        }

        // Restore tasks
        for taskId in action.taskIds {
            guard let task = try? await taskService.getTask(id: taskId),
                  let snapshot = action.before[taskId] else {
                continue
            }

            var updated = task
            restoreFromSnapshot(&updated, snapshot: snapshot)

            try? await taskService.updateTask(updated)
        }

        clearUndo()
        return true
    }

    // MARK: - Check if Undo Available

    func hasUndoableAction() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: STORAGE_KEY),
              let action = try? JSONDecoder().decode(UndoAction.self, from: data) else {
            return false
        }

        let elapsed = Date().timeIntervalSince(action.timestamp)
        return elapsed <= UNDO_TIMEOUT_SECONDS
    }

    func getUndoActionDescription() -> String? {
        guard let data = UserDefaults.standard.data(forKey: STORAGE_KEY),
              let action = try? JSONDecoder().decode(UndoAction.self, from: data) else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(action.timestamp)
        guard elapsed <= UNDO_TIMEOUT_SECONDS else {
            return nil
        }

        switch action.type {
        case .complete:
            return "復原完成"
        case .skip:
            return "復原跳過"
        case .batchPostpone:
            return "復原延後 \(action.taskIds.count) 個任務"
        case .batchComplete:
            return "復原完成 \(action.taskIds.count) 個任務"
        case .batchSkip:
            return "復原跳過 \(action.taskIds.count) 個任務"
        }
    }

    // MARK: - Clear

    func clearUndo() {
        UserDefaults.standard.removeValue(forKey: STORAGE_KEY)
    }

    // MARK: - Helpers

    private func snapshotTask(_ task: Task) -> TaskSnapshot {
        return TaskSnapshot(
            state: task.state.rawValue,
            doneAt: task.doneAt,
            skippedAt: task.skippedAt,
            plannedWorkDate: task.plannedWorkDate,
            committedWeekStartDate: task.committedWeekStartDate,
            isTodayFocus: task.isTodayFocus,
            isDateLocked: task.isDateLocked
        )
    }

    private func restoreFromSnapshot(_ task: inout Task, snapshot: TaskSnapshot) {
        if let state = TaskState(rawValue: snapshot.state) {
            task.state = state
        }
        task.doneAt = snapshot.doneAt
        task.skippedAt = snapshot.skippedAt
        task.plannedWorkDate = snapshot.plannedWorkDate
        task.committedWeekStartDate = snapshot.committedWeekStartDate
        task.isTodayFocus = snapshot.isTodayFocus
        task.isDateLocked = snapshot.isDateLocked
    }
}
