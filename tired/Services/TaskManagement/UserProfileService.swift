import Foundation
import FirebaseFirestore

// MARK: - User Profile Service
@MainActor
class UserProfileService: BaseFirestoreService, ObservableObject {

    static let shared = UserProfileService()

    private let COLLECTION = "user_profiles"

    @Published var profile: UserProfile?

    // MARK: - CRUD Operations

    func createProfile(_ profile: UserProfile) async throws {
        var newProfile = profile
        newProfile.createdAt = Date()
        newProfile.updatedAt = Date()

        try await create(newProfile, collection: COLLECTION)
    }

    func updateProfile(_ profile: UserProfile) async throws {
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()

        try await update(updatedProfile, collection: COLLECTION)
    }

    func getProfile(userId: String) async throws -> UserProfile? {
        let profiles = try await query(
            collection: COLLECTION,
            filters: [.equals(field: "userId", value: userId)],
            limit: 1,
            as: UserProfile.self
        )
        return profiles.first
    }

    func getOrCreateProfile(userId: String) async throws -> UserProfile {
        if let existing = try await getProfile(userId: userId) {
            return existing
        }

        let newProfile = UserProfile(
            userId: userId,
            timeZone: TimeZone.current.identifier
        )

        try await createProfile(newProfile)
        return newProfile
    }

    // MARK: - Profile Updates

    func updateCapacity(profile: UserProfile, weekday: Int, weekend: Int) async throws {
        var updated = profile
        updated.weekdayCapacityMin = weekday
        updated.weekendCapacityMin = weekend

        try await updateProfile(updated)
    }

    func updateTimeZone(profile: UserProfile, timeZone: String) async throws {
        var updated = profile
        updated.timeZone = timeZone

        try await updateProfile(updated)
    }

    func updateFocusSettings(
        profile: UserProfile,
        workDuration: Int,
        shortBreak: Int,
        longBreak: Int
    ) async throws {
        var updated = profile
        updated.focusWorkDuration = workDuration
        updated.focusShortBreak = shortBreak
        updated.focusLongBreak = longBreak

        try await updateProfile(updated)
    }

    func updateNotificationSettings(
        profile: UserProfile,
        dailyReminderTime: String?,
        deadlineAlertDays: Int
    ) async throws {
        var updated = profile
        updated.dailyTodayReminderTime = dailyReminderTime
        updated.deadlineAlertDays = deadlineAlertDays

        try await updateProfile(updated)
    }

    // MARK: - Session Tracking

    func updateLastOpenDate(profile: UserProfile, date: Date) async throws {
        var updated = profile
        updated.lastOpenDate = date
        updated.lastTodayOpenAt = Date()

        try await updateProfile(updated)
    }

    func updateLastFocusResetDate(profile: UserProfile, date: Date) async throws {
        var updated = profile
        updated.lastFocusResetDate = date

        try await updateProfile(updated)
    }

    // MARK: - Card Tracking

    func markCardShown(profile: UserProfile, cardType: CardType, date: Date) async throws {
        var updated = profile

        switch cardType {
        case .gap:
            updated.lastGapCardDate = date
        case .todayOverload:
            updated.lastTodayOverloadCardDate = date
        case .backlogCleanup:
            updated.lastBacklogCleanupCardDate = date
        case .closing:
            updated.lastClosingCardDate = date
        case .thisWeekNudge:
            updated.lastThisWeekNudgeCardDate = date
        case .focusContinue:
            updated.lastFocusContinueCardDate = date
        case .weeklyReview:
            updated.lastWeeklyReviewDate = date
        case .strong:
            updated.lastStrongCardDate = date
        }

        try await updateProfile(updated)
    }

    // MARK: - Streak & Achievements

    func updateStreak(profile: UserProfile, newStreak: Int, date: Date) async throws {
        var updated = profile
        updated.streakDays = newStreak
        updated.lastStreakDate = date

        try await updateProfile(updated)
    }

    func incrementCompletedTasks(profile: UserProfile, count: Int = 1) async throws {
        var updated = profile
        updated.totalCompletedTasks += count

        try await updateProfile(updated)
    }

    func addAchievement(profile: UserProfile, achievementId: String) async throws {
        var updated = profile
        if !updated.achievements.contains(achievementId) {
            updated.achievements.append(achievementId)
            try await updateProfile(updated)
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(
        profile: UserProfile,
        termId: String,
        userStatus: UserStatus
    ) async throws {
        var updated = profile
        updated.currentTermId = termId
        updated.userStatus = userStatus
        updated.lastTermChangeAt = Date()

        try await updateProfile(updated)
    }
}

// MARK: - Card Type
enum CardType {
    case gap
    case todayOverload
    case backlogCleanup
    case closing
    case thisWeekNudge
    case focusContinue
    case weeklyReview
    case strong
}
