import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    var userId: String

    var timeZone: String
    var weekdayCapacityMin: Int
    var weekendCapacityMin: Int

    var currentTermId: String?
    var previousTermId: String?
    var lastTermChangeAt: Date?
    var lastTermCleanupHandledAt: Date?

    var dailyTodayReminderTime: String?
    var deadlineAlertDays: Int

    var enableFocusMode: Bool
    var focusWorkDuration: Int
    var focusShortBreak: Int
    var focusLongBreak: Int
    var focusMuteNotifications: Bool
    var focusLockNavigation: Bool
    var focusBackgroundSound: String?

    var enableClosingCard: Bool
    var enableWeeklyReviewCard: Bool

    var lastFocusResetDate: Date?
    var lastOpenDate: Date?
    var lastTodayOpenAt: Date?

    var lastGapCardDate: Date?
    var lastTodayOverloadCardDate: Date?
    var lastBacklogCleanupCardDate: Date?
    var lastClosingCardDate: Date?
    var lastThisWeekNudgeCardDate: Date?
    var lastFocusContinueCardDate: Date?
    var lastWeeklyReviewDate: Date?
    var lastStrongCardDate: Date?

    var streakDays: Int
    var lastStreakDate: Date?
    var totalCompletedTasks: Int
    var achievements: [String]

    var estimationAccuracy: Double

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timeZone = "time_zone"
        case weekdayCapacityMin = "weekday_capacity_min"
        case weekendCapacityMin = "weekend_capacity_min"
        case currentTermId = "current_term_id"
        case previousTermId = "previous_term_id"
        case lastTermChangeAt = "last_term_change_at"
        case lastTermCleanupHandledAt = "last_term_cleanup_handled_at"
        case dailyTodayReminderTime = "daily_today_reminder_time"
        case deadlineAlertDays = "deadline_alert_days"
        case enableFocusMode = "enable_focus_mode"
        case focusWorkDuration = "focus_work_duration"
        case focusShortBreak = "focus_short_break"
        case focusLongBreak = "focus_long_break"
        case focusMuteNotifications = "focus_mute_notifications"
        case focusLockNavigation = "focus_lock_navigation"
        case focusBackgroundSound = "focus_background_sound"
        case enableClosingCard = "enable_closing_card"
        case enableWeeklyReviewCard = "enable_weekly_review_card"
        case lastFocusResetDate = "last_focus_reset_date"
        case lastOpenDate = "last_open_date"
        case lastTodayOpenAt = "last_today_open_at"
        case lastGapCardDate = "last_gap_card_date"
        case lastTodayOverloadCardDate = "last_today_overload_card_date"
        case lastBacklogCleanupCardDate = "last_backlog_cleanup_card_date"
        case lastClosingCardDate = "last_closing_card_date"
        case lastThisWeekNudgeCardDate = "last_this_week_nudge_card_date"
        case lastFocusContinueCardDate = "last_focus_continue_card_date"
        case lastWeeklyReviewDate = "last_weekly_review_date"
        case lastStrongCardDate = "last_strong_card_date"
        case streakDays = "streak_days"
        case lastStreakDate = "last_streak_date"
        case totalCompletedTasks = "total_completed_tasks"
        case achievements
        case estimationAccuracy = "estimation_accuracy"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: String) {
        self.userId = userId
        self.timeZone = TimeZone.current.identifier
        self.weekdayCapacityMin = 180  // 3 hours default
        self.weekendCapacityMin = 240  // 4 hours default
        self.deadlineAlertDays = 1
        self.enableFocusMode = true
        self.focusWorkDuration = 25
        self.focusShortBreak = 5
        self.focusLongBreak = 15
        self.focusMuteNotifications = false
        self.focusLockNavigation = false
        self.enableClosingCard = true
        self.enableWeeklyReviewCard = true
        self.streakDays = 0
        self.totalCompletedTasks = 0
        self.achievements = []
        self.estimationAccuracy = 1.0
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
