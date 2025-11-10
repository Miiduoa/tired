import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private override init() {
        super.init()
    }

    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("❌ 請求通知權限失敗: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - FCM Token Registration
    
    /// 註冊設備 Token 到服務器
    func registerDeviceToken(_ token: Data, userId: String) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/notifications/register")
        else {
            print("📱 Device Token (offline): \(tokenString)")
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
        
        print("✅ Device Token registered successfully")
    }
    
    /// 獲取 FCM Token
    func getFCMToken() async -> String? {
        return await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("❌ 獲取 FCM Token 失敗: \(error)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: token)
                }
            }
        }
    }
    
    /// 訂閱主題
    func subscribe(to topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    print("✅ 訂閱主題成功: \(topic)")
                    continuation.resume()
                }
            }
        }
    }
    
    /// 取消訂閱主題
    func unsubscribe(from topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    print("✅ 取消訂閱主題成功: \(topic)")
                    continuation.resume()
                }
            }
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

    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        after seconds: TimeInterval,
        userInfo: [String: Any] = [:]
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        try await UNUserNotificationCenter.current().add(request)
        print("📅 排程通知成功: \(title) 於 \(seconds)秒後")
    }
    
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        at date: Date,
        userInfo: [String: Any] = [:]
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        try await UNUserNotificationCenter.current().add(request)
        print("📅 排程通知成功: \(title) 於 \(date)")
    }
    
    func cancelNotification(withId id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        print("🗑️ 取消通知: \(id)")
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ 取消所有通知")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    // MARK: - Badge Management
    
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("❌ 設置 Badge 失敗: \(error)")
            }
        }
    }
    
    func clearBadge() {
        setBadgeCount(0)
    }
    
    func incrementBadge() {
        Task {
            let current = await UIApplication.shared.applicationIconBadgeNumber
            setBadgeCount(current + 1)
        }
    }
    
    func decrementBadge() {
        Task {
            let current = await UIApplication.shared.applicationIconBadgeNumber
            setBadgeCount(max(0, current - 1))
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // 前台顯示通知
        return [.banner, .sound, .badge]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // 用戶點擊通知後的處理
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo) { action in
            if let action = action {
                NotificationCenter.default.post(name: .handleNotificationAction, object: action)
            }
        }
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

// MARK: - NotificationCenter Extension

extension Notification.Name {
    static let handleNotificationAction = Notification.Name("handleNotificationAction")
}

