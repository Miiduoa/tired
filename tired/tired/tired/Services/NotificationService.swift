import Foundation
import UserNotifications

/// A service to manage local notifications for tasks and events.
class NotificationService {
    static let shared = NotificationService()
    private let notificationCenter = UNUserNotificationCenter.current()

    /// Requests authorization to send notifications.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ Error requesting notification authorization: \(error)")
            return false
        }
    }

    /// Schedules a local notification for a given task.
    /// - Parameters:
    ///   - task: The task for which to schedule a reminder.
    ///   - reminderOffset: How long before the deadline to show the notification. Defaults to 15 minutes.
    func scheduleNotification(for task: Task, reminderOffset: TimeInterval = 15 * 60) {
        guard let taskId = task.id else { return }
        
        // Always clear any pending notification first to avoid duplicates
        cancelNotification(withIdentifier: "task-\(taskId)")
        
        // Respect reminder toggle
        guard task.hasReminder else { return }
        
        // Choose explicit reminder time first, then fallback to deadline offset
        let triggerDate: Date
        if let reminderAt = task.reminderAt {
            triggerDate = reminderAt
        } else if let deadline = task.deadlineAt {
            triggerDate = deadline.addingTimeInterval(-reminderOffset)
        } else {
            return
        }
        
        // Only schedule notifications in the future
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "任務即將到期"
        content.body = task.title
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: "task-\(taskId)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification for task \(taskId): \(error)")
            } else {
                print("✅ Notification scheduled for task \(taskId) at \(triggerDate)")
            }
        }
    }
    
    /// Schedules a local notification for a given event.
    /// - Parameters:
    ///   - event: The event for which to schedule a reminder.
    ///   - reminderOffset: How long before the start time to show the notification. Defaults to 15 minutes.
    func scheduleNotification(for event: Event, reminderOffset: TimeInterval = 15 * 60) {
        guard let eventId = event.id else { return }
        
        let triggerDate = event.startAt.addingTimeInterval(-reminderOffset)
        
        // Only schedule notifications in the future
        guard triggerDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "活動即將開始"
        content.body = event.title
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: "event-\(eventId)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification for event \(eventId): \(error)")
            } else {
                print("✅ Notification scheduled for event \(eventId) at \(triggerDate)")
            }
        }
    }

    /// Cancels a pending notification for a specific task or event.
    /// - Parameter identifier: The unique identifier for the notification (e.g., "task-123" or "event-456").
    func cancelNotification(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("ℹ️ Canceled notification with identifier: \(identifier)")
    }
    
    /// Cancels a pending notification for a specific task.
    func cancelNotification(for task: Task) {
        guard let taskId = task.id else { return }
        cancelNotification(withIdentifier: "task-\(taskId)")
    }
    
    /// Cancels a pending notification for a specific event.
    func cancelNotification(for event: Event) {
        guard let eventId = event.id else { return }
        cancelNotification(withIdentifier: "event-\(eventId)")
    }

    // MARK: - Moodle-like Notifications

    /// 通知教師有新的作業提交
    /// - Parameters:
    ///   - studentName: 學生姓名
    ///   - assignmentTitle: 作業標題
    ///   - organizationName: 組織名稱
    func notifyTeacherOfSubmission(
        studentName: String,
        assignmentTitle: String,
        organizationName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "📝 新的作業提交"
        content.body = "\(studentName) 已提交「\(assignmentTitle)」（\(organizationName)）"
        content.sound = .default
        content.categoryIdentifier = "ASSIGNMENT_SUBMISSION"

        // 立即通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "submission-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error sending submission notification: \(error)")
            } else {
                print("✅ Submission notification sent to teacher")
            }
        }
    }

    /// 通知學生成績已發布
    /// - Parameters:
    ///   - assignmentTitle: 作業標題
    ///   - grade: 成績
    ///   - organizationName: 組織名稱
    func notifyStudentOfGrade(
        assignmentTitle: String,
        grade: Grade,
        organizationName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "✅ 成績已發布"
        content.body = "「\(assignmentTitle)」成績：\(grade.displayGrade)（\(organizationName)）"
        content.sound = .default
        content.categoryIdentifier = "GRADE_RELEASED"

        // 立即通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "grade-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error sending grade notification: \(error)")
            } else {
                print("✅ Grade notification sent to student")
            }
        }
    }

    /// 通知學生有新的公告
    /// - Parameters:
    ///   - announcementTitle: 公告標題
    ///   - organizationName: 組織名稱
    func notifyOfAnnouncement(
        announcementTitle: String,
        organizationName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "📢 新公告"
        content.body = "\(announcementTitle)（\(organizationName)）"
        content.sound = .default
        content.categoryIdentifier = "ANNOUNCEMENT"

        // 立即通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "announcement-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error sending announcement notification: \(error)")
            } else {
                print("✅ Announcement notification sent")
            }
        }
    }

    /// 通知用戶有新的評論
    /// - Parameters:
    ///   - commenterName: 評論者姓名
    ///   - postTitle: 貼文標題
    ///   - organizationName: 組織名稱
    func notifyOfComment(
        commenterName: String,
        postTitle: String,
        organizationName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "💬 新評論"
        content.body = "\(commenterName) 評論了「\(postTitle)」（\(organizationName)）"
        content.sound = .default
        content.categoryIdentifier = "COMMENT"

        // 立即通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "comment-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error sending comment notification: \(error)")
            } else {
                print("✅ Comment notification sent")
            }
        }
    }
}
