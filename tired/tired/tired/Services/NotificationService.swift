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
        guard let deadline = task.deadlineAt, let taskId = task.id else { return }

        let triggerDate = deadline.addingTimeInterval(-reminderOffset)
        
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
}
