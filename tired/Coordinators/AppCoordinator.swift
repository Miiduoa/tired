import Foundation
import SwiftUI
import Combine

// MARK: - App Coordinator
@MainActor
class AppCoordinator: ObservableObject {

    // MARK: - Published Properties

    @Published var userId: String?
    @Published var userProfile: UserProfile?
    @Published var currentTerm: TermConfig?
    @Published var isOnboardingComplete: Bool = false
    @Published var isLoading: Bool = true

    // Focus recovery
    @Published var showFocusRecovery: Bool = false
    @Published var shouldRestoreFocus: Bool = false
    @Published var crashedFocusState: FocusState?
    @Published var crashedFocusTask: Task?

    // Term cleanup
    @Published var showTermCleanup: Bool = false

    // Services
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared
    private let taskService = TaskService.shared

    // Session
    private var lastOpenDate: Date?

    // MARK: - Initialization

    func initialize(userId: String) async {
        self.userId = userId
        await loadUserData()
        await handleAppStartup()
        isLoading = false
    }

    // MARK: - Load User Data

    private func loadUserData() async {
        guard let userId = userId else { return }

        do {
            // Load profile
            if let profile = try await profileService.getProfile(userId: userId) {
                self.userProfile = profile

                // Load current term
                if let termId = profile.currentTermId {
                    if let term = try await termService.getTermByTermId(userId: userId, termId: termId) {
                        self.currentTerm = term
                    }
                }

                isOnboardingComplete = profile.isCoreOnboardingDone()
            } else {
                isOnboardingComplete = false
            }

        } catch {
            print("❌ Error loading user data: \(error.localizedDescription)")
        }
    }

    // MARK: - App Startup Flow

    private func handleAppStartup() async {
        guard let profile = userProfile, let userId = userId else { return }

        let todayDate = Date()
        lastOpenDate = profile.lastOpenDate

        // Update last open date
        do {
            try await profileService.updateLastOpenDate(profile: profile, date: todayDate)
        } catch {
            print("❌ Error updating last open date: \(error.localizedDescription)")
        }

        // Check for crashed focus session
        if let focusState = await FocusModeViewModel.restoreFocusIfNeeded() {
            // Load the task
            do {
                if let task = try await taskService.getTask(id: focusState.taskId) {
                    crashedFocusState = focusState
                    crashedFocusTask = task
                    showFocusRecovery = true
                }
            } catch {
                print("❌ Error loading crashed focus task: \(error.localizedDescription)")
                // Clear invalid focus state
                UserDefaults.standard.removeValue(forKey: "focus_state")
            }
        }

        // Reset today focus if it's a new day
        if let lastOpen = lastOpenDate,
           !DateUtils.isSameDay(lastOpen, todayDate) {
            await resetTodayFocus(userId: userId)
        }

        // Update streak
        await updateStreakIfNeeded(userId: userId, todayDate: todayDate)

        // Check if term cleanup is needed
        if needsTermCleanup() {
            // Delay showing term cleanup to avoid conflict with focus recovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showTermCleanup = true
            }
        }

        // TODO: Show cards after delay
    }

    // MARK: - Focus Recovery

    func restoreFocusSession() {
        // Will be handled by the view showing FocusMode with the restored task
        showFocusRecovery = false
        shouldRestoreFocus = true
    }

    func focusRestorationCompleted() {
        shouldRestoreFocus = false
        crashedFocusState = nil
        crashedFocusTask = nil
    }

    func discardFocusSession() async {
        guard let state = crashedFocusState, let task = crashedFocusTask else { return }

        // Mark as interrupted and save work session
        let elapsedMin = Int((Date().timeIntervalSince(state.sessionStart)) / 60)
        let session = WorkSession(
            startAt: state.sessionStart,
            endAt: Date(),
            durationMin: elapsedMin,
            pomodoroCount: state.pomodoroCount,
            breakSessions: state.breakSessions,
            wasInterrupted: true
        )

        do {
            try await taskService.addWorkSession(task, session: session)
            ToastManager.shared.showInfo("已儲存中斷的專注記錄")
        } catch {
            print("❌ Error saving interrupted session: \(error.localizedDescription)")
        }

        // Clear focus state
        UserDefaults.standard.removeValue(forKey: "focus_state")
        crashedFocusState = nil
        crashedFocusTask = nil
        showFocusRecovery = false
    }

    // MARK: - Today Focus Reset

    private func resetTodayFocus(userId: String) async {
        do {
            let allTasks = try await taskService.getTasks(userId: userId)
            for var task in allTasks where task.isTodayFocus {
                task.isTodayFocus = false
                try await taskService.updateTask(task)
            }
        } catch {
            print("❌ Error resetting today focus: \(error.localizedDescription)")
        }
    }

    // MARK: - Streak Update Helper

    private func updateStreakIfNeeded(userId: String, todayDate: Date) async {
        // Only update if there were completed tasks yesterday
        guard let lastOpen = lastOpenDate else { return }

        let yesterday = DateUtils.addDays(todayDate, -1)
        if DateUtils.isSameDay(lastOpen, yesterday) {
            // App opened day after completion - check and update streak
            do {
                let completedTasks = try await taskService.getCompletedTasks(
                    userId: userId,
                    fromDate: DateUtils.addDays(todayDate, -7),
                    toDate: todayDate
                )
                await updateStreak(completedTasks: completedTasks)
            } catch {
                print("❌ Error updating streak: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Onboarding

    func checkOnboardingStatus() {
        Task {
            await loadUserData()
        }
    }

    // MARK: - Profile Updates

    func updateProfile(_ profile: UserProfile) async {
        do {
            try await profileService.updateProfile(profile)
            self.userProfile = profile
        } catch {
            print("❌ Error updating profile: \(error.localizedDescription)")
        }
    }

    func updateCapacity(weekday: Int, weekend: Int) async {
        guard let profile = userProfile else { return }

        do {
            try await profileService.updateCapacity(profile: profile, weekday: weekday, weekend: weekend)
            await loadUserData()
        } catch {
            print("❌ Error updating capacity: \(error.localizedDescription)")
        }
    }

    // MARK: - Term Management

    func switchTerm(to termId: String) async {
        guard let userId = userId, let profile = userProfile else { return }

        do {
            try await termService.switchTerm(
                userId: userId,
                newTermId: termId,
                profile: profile,
                profileService: profileService
            )
            await loadUserData()
        } catch {
            print("❌ Error switching term: \(error.localizedDescription)")
        }
    }

    func needsTermCleanup() -> Bool {
        guard let profile = userProfile else { return false }
        return termService.needsTermCleanup(profile: profile)
    }

    func markTermCleanupHandled() async {
        guard let profile = userProfile else { return }

        do {
            try await termService.markTermCleanupHandled(profile: profile, profileService: profileService)
            await loadUserData()
        } catch {
            print("❌ Error marking term cleanup handled: \(error.localizedDescription)")
        }
    }

    // MARK: - Streak Update

    func updateStreak(completedTasks: [Task]) async {
        guard let profile = userProfile else { return }

        let todayDate = Date()
        let yesterday = DateUtils.addDays(todayDate, -1)

        let todayCompleted = completedTasks.filter { task in
            guard let doneAt = task.doneAt else { return false }
            return DateUtils.isSameDay(doneAt, todayDate)
        }

        guard !todayCompleted.isEmpty else { return }

        let yesterdayCompleted = completedTasks.filter { task in
            guard let doneAt = task.doneAt else { return false }
            return DateUtils.isSameDay(doneAt, yesterday)
        }

        let newStreak: Int
        if yesterdayCompleted.isEmpty && profile.streakDays > 0 {
            newStreak = 1
        } else {
            newStreak = profile.streakDays + 1
        }

        do {
            try await profileService.updateStreak(profile: profile, newStreak: newStreak, date: todayDate)
            await loadUserData()
        } catch {
            print("❌ Error updating streak: \(error.localizedDescription)")
        }
    }
}
