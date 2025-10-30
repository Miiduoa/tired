import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TiredApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 初始化 Firebase（只初始化一次，避免重複初始化導致錯誤）
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // 初始化 Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ 無法從 GoogleService-Info.plist 讀取 CLIENT_ID")
            return true
        }
        
        // 避免重複配置 Google Sign-In
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            print("✅ Google Sign-In 已配置，CLIENT_ID: \(clientId.prefix(30))...")
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Google Sign-In 回呼
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }
}
