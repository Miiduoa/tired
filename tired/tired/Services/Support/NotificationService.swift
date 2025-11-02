import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private override init() {}

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { _, _ in }
    }
    
    /// 註冊設備 Token 到服務器
    func registerDeviceToken(_ token: Data, userId: String) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/notifications/register")
        else {
            print("Device Token (offline): \(tokenString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = [
            "deviceToken": tokenString,
            "userId": userId,
            "platform": "ios"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "NotificationService", code: -1)
        }
    }
    
    /// 處理推播通知
    func handleNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (NotificationAction?) -> Void) {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            completion(nil)
            return
        }
        
        let action: NotificationAction
        switch type {
        case .broadcast:
            action = userInfo["broadcastId"] as? String != nil ? .openBroadcast(userInfo["broadcastId"] as! String) : .openBroadcastList
        case .attendance:
            action = userInfo["sessionId"] as? String != nil ? .openAttendance(userInfo["sessionId"] as! String) : .openAttendanceList
        case .clock:
            action = .openClock
        case .event:
            action = userInfo["eventId"] as? String != nil ? .openEvent(userInfo["eventId"] as! String) : .openEventList
        case .message:
            action = userInfo["conversationId"] as? String != nil ? .openConversation(userInfo["conversationId"] as! String) : .openMessageList
        case .announcement:
            action = .openAnnouncements
        }
        
        completion(action)
    }

    func scheduleLocalNotification(id: String, title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }
    
    func clearBadge() {
        setBadgeCount(0)
    }

    // Bring banner even in foreground (optional)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

// MARK: - 數據結構

enum NotificationType: String {
    case broadcast, attendance, clock, event, message, announcement
}

enum NotificationAction {
    case openBroadcast(String)
    case openBroadcastList
    case openAttendance(String)
    case openAttendanceList
    case openClock
    case openEvent(String)
    case openEventList
    case openConversation(String)
    case openMessageList
    case openAnnouncements
}

