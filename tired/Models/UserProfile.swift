import Foundation

// MARK: - User Profile Model
struct UserProfile: Codable, Identifiable {
    var id: String
    var userId: String

    // Time Settings
    var timeZone: String
    var weekdayCapacityMin: Int
    var weekendCapacityMin: Int

    // Term Management
    var currentTermId: String?
    var previousTermId: String?
    var lastTermChangeAt: Date?
    var lastTermCleanupHandledAt: Date?

    // User Status
    var userStatus: UserStatus?

    // Notification Settings
    var dailyTodayReminderTime: String? // "HH:mm" format
    var deadlineAlertDays: Int

    // Focus Mode Settings
    var enableFocusMode: Bool
    var focusWorkDuration: Int // minutes
    var focusShortBreak: Int   // minutes
    var focusLongBreak: Int    // minutes
    var focusMuteNotifications: Bool
    var focusLockNavigation: Bool
    var focusBackgroundSound: String?

    // Card Settings
    var enableClosingCard: Bool
    var enableWeeklyReviewCard: Bool

    // Session Tracking
    var lastFocusResetDate: Date?
    var lastOpenDate: Date?
    var lastTodayOpenAt: Date?

    // Card Last Shown Dates
    var lastGapCardDate: Date?
    var lastTodayOverloadCardDate: Date?
    var lastBacklogCleanupCardDate: Date?
    var lastClosingCardDate: Date?
    var lastThisWeekNudgeCardDate: Date?
    var lastFocusContinueCardDate: Date?
    var lastWeeklyReviewDate: Date?
    var lastStrongCardDate: Date?

    // Achievements
    var streakDays: Int
    var lastStreakDate: Date?
    var totalCompletedTasks: Int
    var achievements: [String]

    // Estimation
    var estimationAccuracy: Double // 0.0 to 1.0

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        timeZone: String = TimeZone.current.identifier,
        weekdayCapacityMin: Int = 180, // 3 hours default
        weekendCapacityMin: Int = 240, // 4 hours default
        currentTermId: String? = nil,
        previousTermId: String? = nil,
        lastTermChangeAt: Date? = nil,
        lastTermCleanupHandledAt: Date? = nil,
        userStatus: UserStatus? = nil,
        dailyTodayReminderTime: String? = "09:00",
        deadlineAlertDays: Int = 1,
        enableFocusMode: Bool = true,
        focusWorkDuration: Int = 25,
        focusShortBreak: Int = 5,
        focusLongBreak: Int = 15,
        focusMuteNotifications: Bool = true,
        focusLockNavigation: Bool = false,
        focusBackgroundSound: String? = nil,
        enableClosingCard: Bool = true,
        enableWeeklyReviewCard: Bool = true,
        lastFocusResetDate: Date? = nil,
        lastOpenDate: Date? = nil,
        lastTodayOpenAt: Date? = nil,
        lastGapCardDate: Date? = nil,
        lastTodayOverloadCardDate: Date? = nil,
        lastBacklogCleanupCardDate: Date? = nil,
        lastClosingCardDate: Date? = nil,
        lastThisWeekNudgeCardDate: Date? = nil,
        lastFocusContinueCardDate: Date? = nil,
        lastWeeklyReviewDate: Date? = nil,
        lastStrongCardDate: Date? = nil,
        streakDays: Int = 0,
        lastStreakDate: Date? = nil,
        totalCompletedTasks: Int = 0,
        achievements: [String] = [],
        estimationAccuracy: Double = 0.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.timeZone = timeZone
        self.weekdayCapacityMin = weekdayCapacityMin
        self.weekendCapacityMin = weekendCapacityMin
        self.currentTermId = currentTermId
        self.previousTermId = previousTermId
        self.lastTermChangeAt = lastTermChangeAt
        self.lastTermCleanupHandledAt = lastTermCleanupHandledAt
        self.userStatus = userStatus
        self.dailyTodayReminderTime = dailyTodayReminderTime
        self.deadlineAlertDays = deadlineAlertDays
        self.enableFocusMode = enableFocusMode
        self.focusWorkDuration = focusWorkDuration
        self.focusShortBreak = focusShortBreak
        self.focusLongBreak = focusLongBreak
        self.focusMuteNotifications = focusMuteNotifications
        self.focusLockNavigation = focusLockNavigation
        self.focusBackgroundSound = focusBackgroundSound
        self.enableClosingCard = enableClosingCard
        self.enableWeeklyReviewCard = enableWeeklyReviewCard
        self.lastFocusResetDate = lastFocusResetDate
        self.lastOpenDate = lastOpenDate
        self.lastTodayOpenAt = lastTodayOpenAt
        self.lastGapCardDate = lastGapCardDate
        self.lastTodayOverloadCardDate = lastTodayOverloadCardDate
        self.lastBacklogCleanupCardDate = lastBacklogCleanupCardDate
        self.lastClosingCardDate = lastClosingCardDate
        self.lastThisWeekNudgeCardDate = lastThisWeekNudgeCardDate
        self.lastFocusContinueCardDate = lastFocusContinueCardDate
        self.lastWeeklyReviewDate = lastWeeklyReviewDate
        self.lastStrongCardDate = lastStrongCardDate
        self.streakDays = streakDays
        self.lastStreakDate = lastStreakDate
        self.totalCompletedTasks = totalCompletedTasks
        self.achievements = achievements
        self.estimationAccuracy = estimationAccuracy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - User Profile Helpers
extension UserProfile {
    // Check if core onboarding is complete
    func isCoreOnboardingDone() -> Bool {
        return currentTermId != nil
    }

    // Get capacity for a specific date
    func capacityMinutes(for date: Date) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 7 = Saturday
        return (weekday == 1 || weekday == 7) ? weekendCapacityMin : weekdayCapacityMin
    }

    // Check if user needs academic features
    var needsAcademicFeatures: Bool {
        return userStatus?.needsAcademicFeatures ?? true
    }
}
