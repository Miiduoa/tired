import Foundation
import Combine

/// 專注模式狀態管理（含崩潰恢復）
class FocusState: ObservableObject {
    static let shared = FocusState()

    @Published var isActive: Bool = false
    @Published var currentTaskId: String?
    @Published var sessionStart: Date?
    @Published var pomodoroCount: Int = 0
    @Published var breakSessions: Int = 0
    @Published var isBreak: Bool = false
    @Published var wasInterrupted: Bool = false

    private let storageKey = "focus_state"

    private init() {
        loadState()
    }

    struct StoredFocusState: Codable {
        let taskId: String
        let sessionStart: Date
        let pomodoroCount: Int
        let breakSessions: Int
        let isBreak: Bool
        let wasInterrupted: Bool
    }

    /// 開始專注會話
    func startFocus(taskId: String) {
        isActive = true
        currentTaskId = taskId
        sessionStart = Date()
        pomodoroCount = 0
        breakSessions = 0
        isBreak = false
        wasInterrupted = false

        saveState()
    }

    /// 結束專注會話
    func endFocus(interrupted: Bool = false) -> WorkSession? {
        guard let taskId = currentTaskId,
              let start = sessionStart else {
            return nil
        }

        let end = Date()
        let duration = DateUtils.diffInMinutes(end, start)

        let session = WorkSession(
            startAt: start,
            endAt: end,
            durationMin: duration,
            pomodoroCount: pomodoroCount,
            breakSessions: breakSessions,
            wasInterrupted: interrupted || wasInterrupted
        )

        // 清除狀態
        isActive = false
        currentTaskId = nil
        sessionStart = nil
        pomodoroCount = 0
        breakSessions = 0
        isBreak = false
        wasInterrupted = false

        clearStorage()

        return session
    }

    /// 記錄完成的番茄鐘
    func completePomodoro() {
        pomodoroCount += 1
        saveState()
    }

    /// 開始休息
    func startBreak() {
        isBreak = true
        breakSessions += 1
        saveState()
    }

    /// 結束休息
    func endBreak() {
        isBreak = false
        saveState()
    }

    /// 保存狀態到 localStorage
    private func saveState() {
        guard let taskId = currentTaskId,
              let start = sessionStart else {
            return
        }

        let state = StoredFocusState(
            taskId: taskId,
            sessionStart: start,
            pomodoroCount: pomodoroCount,
            breakSessions: breakSessions,
            isBreak: isBreak,
            wasInterrupted: wasInterrupted
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 從 localStorage 加載狀態
    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(StoredFocusState.self, from: data) else {
            return
        }

        currentTaskId = state.taskId
        sessionStart = state.sessionStart
        pomodoroCount = state.pomodoroCount
        breakSessions = state.breakSessions
        isBreak = state.isBreak
        wasInterrupted = state.wasInterrupted
        isActive = true
    }

    /// 清除存儲
    private func clearStorage() {
        UserDefaults.standard.removeItem(forKey: storageKey)
    }

    /// 檢查是否有未完成的會話需要恢復
    func hasUnfinishedSession() -> (hasSession: Bool, elapsedMin: Int, taskId: String?) {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(StoredFocusState.self, from: data) else {
            return (false, 0, nil)
        }

        let elapsedMin = DateUtils.diffInMinutes(Date(), state.sessionStart)

        if elapsedMin < 1 {
            clearStorage()
            return (false, 0, nil)
        }

        return (true, elapsedMin, state.taskId)
    }

    /// 恢復未完成的會話（用戶選擇恢復）
    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(StoredFocusState.self, from: data) else {
            return
        }

        currentTaskId = state.taskId
        sessionStart = state.sessionStart
        pomodoroCount = state.pomodoroCount
        breakSessions = state.breakSessions
        isBreak = false
        wasInterrupted = true
        isActive = true
    }

    /// 放棄未完成的會話
    func discardSession() {
        clearStorage()
        isActive = false
        currentTaskId = nil
        sessionStart = nil
        pomodoroCount = 0
        breakSessions = 0
        isBreak = false
        wasInterrupted = false
    }
}
