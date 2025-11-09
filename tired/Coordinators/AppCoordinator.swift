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
        guard let profile = userProfile else { return }

        let todayDate = Date()
        lastOpenDate = profile.lastOpenDate

        // Update last open date
        do {
            try await profileService.updateLastOpenDate(profile: profile, date: todayDate)
        } catch {
            print("❌ Error updating last open date: \(error.localizedDescription)")
        }

        // TODO: Handle focus reset
        // TODO: Update streak
        // TODO: Show cards after delay
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
