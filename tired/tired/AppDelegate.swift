import UIKit
import Firebase
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 設定推播通知代理
        UNUserNotificationCenter.current().delegate = self
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        
        // 請求推播權限
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs token retrieved: \(deviceToken)")
        #if canImport(FirebaseMessaging)
        // 將 APNs token 設置給 FCM
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // 當 App 在前景時收到推播
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("🔔 Received foreground notification: \(userInfo)")
        
        // 可以在這裡決定前景推播要不要顯示 (e.g., .banner, .list, .sound)
        completionHandler([[.alert, .sound]])
    }

    // 當使用者點擊推播時
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👉 User tapped on notification: \(userInfo)")
        
        // 在這裡處理點擊推播後的跳轉邏輯
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    // 當 FCM token 刷新時
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✨ FCM registration token: \(String(describing: fcmToken))")
        
        guard let token = fcmToken else { return }
        
        // 將此 token 傳遞給 UserService 來更新到 Firestore
        let userService = UserService()
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                do {
                    try await userService.updateFCMToken(userId: userId, token: token)
                    print("✅ FCM token updated successfully for user \(userId)")
                } catch {
                    print("❌ Error updating FCM token: \(error.localizedDescription)")
                }
            }
        }
    }
}
#endif
