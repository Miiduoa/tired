import Foundation
import SwiftUI
import Combine

// MARK: - Focus State (for localStorage backup)
struct FocusState: Codable {
    var taskId: String
    var sessionStart: Date
    var pomodoroCount: Int
    var breakSessions: Int
    var isBreak: Bool
    var wasInterrupted: Bool
    var lastSavedAt: Date
    var remainingSeconds: Int
    var totalSeconds: Int
    var isRunning: Bool
}

// MARK: - Focus Mode View Model
@MainActor
class FocusModeViewModel: ObservableObject {

    @Published var task: Task
    @Published var isRunning: Bool = false
    @Published var isBreak: Bool = false

    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var progress: Double = 1.0

    @Published var pomodoroCount: Int = 0
    @Published var breakCount: Int = 0
    @Published var totalMinutes: Int = 0

    @Published var showEndConfirm: Bool = false

    private var timer: Timer?
    private var sessionStartTime: Date?
    private let taskService = TaskService.shared

    // Settings (from UserProfile)
    private var workDuration: Int = 25 // minutes
    private var shortBreak: Int = 5    // minutes
    private var longBreak: Int = 15    // minutes

    var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init(task: Task, restoreFrom: FocusState? = nil) {
        self.task = task

        // Load settings from UserProfile if available
        loadSettings()

        if let state = restoreFrom {
            // Restore from crashed state
            self.sessionStartTime = state.sessionStart
            self.pomodoroCount = state.pomodoroCount
            self.breakCount = state.breakSessions
            self.isBreak = state.isBreak

            // Calculate elapsed time since last save
            let elapsedSinceLastSave = Date().timeIntervalSince(state.lastSavedAt)
            let adjustedRemaining = max(0, state.remainingSeconds - Int(elapsedSinceLastSave))

            self.remainingSeconds = adjustedRemaining
            self.totalSeconds = state.totalSeconds
            self.progress = adjustedRemaining > 0 ? Double(adjustedRemaining) / Double(state.totalSeconds) : 0

            // Auto-start if it was running
            if state.isRunning && adjustedRemaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startTimer()
                }
            }

            ToastManager.shared.showSuccess("已恢復專注模式")
        } else {
            // Start fresh
            self.sessionStartTime = Date()
            startWorkPeriod()
        }

        // Save focus state to localStorage
        saveFocusState()
    }

    // MARK: - Load Settings

    private func loadSettings() {
        // TODO: Load from UserProfile
        // For now, use defaults
    }

    // MARK: - Timer Control

    func startTimer() {
        guard !isRunning else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            // Timer completed
            timerCompleted()
            return
        }

        remainingSeconds -= 1
        progress = Double(remainingSeconds) / Double(totalSeconds)
        totalMinutes = Int((Date().timeIntervalSince(sessionStartTime ?? Date())) / 60)

        // Save state every 5 seconds to reduce overhead
        if remainingSeconds % 5 == 0 {
            saveFocusState()
        }
    }

    // MARK: - Period Management

    private func startWorkPeriod() {
        isBreak = false
        remainingSeconds = workDuration * 60
        totalSeconds = remainingSeconds
        progress = 1.0
    }

    private func startBreakPeriod() {
        isBreak = true
        breakCount += 1

        // Use long break every 4 pomodoros
        let breakDuration = (pomodoroCount % 4 == 0) ? longBreak : shortBreak
        remainingSeconds = breakDuration * 60
        totalSeconds = remainingSeconds
        progress = 1.0

        saveFocusState()
    }

    private func timerCompleted() {
        pauseTimer()

        if isBreak {
            // Break finished, start next work period
            startWorkPeriod()
            startTimer()
        } else {
            // Work period finished
            pomodoroCount += 1
            startBreakPeriod()
            startTimer()

            // Play sound or notification
            playCompletionSound()
        }

        saveFocusState()
    }

    func skipBreak() {
        guard isBreak else { return }
        pauseTimer()
        startWorkPeriod()
        startTimer()
    }

    // MARK: - End Focus

    func endFocus() async {
        pauseTimer()

        // Calculate total work time
        let elapsedMin = Int((Date().timeIntervalSince(sessionStartTime ?? Date())) / 60)

        // Create work session
        let session = WorkSession(
            startAt: sessionStartTime ?? Date(),
            endAt: Date(),
            durationMin: elapsedMin,
            pomodoroCount: pomodoroCount,
            breakSessions: breakCount,
            wasInterrupted: false
        )

        // Save to task
        do {
            try await taskService.addWorkSession(task, session: session)

            // Clear focus state from localStorage
            clearFocusState()

        } catch {
            print("❌ Error saving work session: \(error.localizedDescription)")
        }
    }

    // MARK: - Focus State Persistence (for crash recovery)

    private func saveFocusState() {
        let state = FocusState(
            taskId: task.id,
            sessionStart: sessionStartTime ?? Date(),
            pomodoroCount: pomodoroCount,
            breakSessions: breakCount,
            isBreak: isBreak,
            wasInterrupted: false,
            lastSavedAt: Date(),
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            isRunning: isRunning
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "focus_state")
        }
    }

    private func clearFocusState() {
        UserDefaults.standard.removeValue(forKey: "focus_state")
    }

    // MARK: - Restoration

    static func restoreFocusIfNeeded() async -> FocusState? {
        guard let data = UserDefaults.standard.data(forKey: "focus_state"),
              let state = try? JSONDecoder().decode(FocusState.self, from: data) else {
            return nil
        }

        // Check if session is still valid (< 24 hours)
        let elapsedMin = Int((Date().timeIntervalSince(state.sessionStart)) / 60)
        if elapsedMin < 24 * 60 {
            return state
        }

        // Session too old, clear it
        UserDefaults.standard.removeValue(forKey: "focus_state")
        return nil
    }

    // MARK: - Sound & Notifications

    private func playCompletionSound() {
        // Play system sound
        #if os(iOS)
        AudioServicesPlaySystemSound(1054) // Notification sound
        #endif
    }
}

#if os(iOS)
import AudioToolbox
#endif
