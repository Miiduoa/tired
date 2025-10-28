import SwiftUI
import FirebaseCore

@main
struct TiredApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    RootTabView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(authService)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseService.shared.configureIfNeeded()
        return true
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            InboxView()
                .tabItem { Label("收件匣", systemImage: "tray") }
            MessagesView()
                .tabItem { Label("訊息", systemImage: "bubble.left.and.bubble.right") }
            GroupHomeView()
                .tabItem { Label("群組", systemImage: "person.3") }
            NavigationStack {
                AccountView()
            }
            .tabItem { Label("我", systemImage: "person.crop.circle") }
        }
    }
}

struct MessagesView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("這裡放聊天清單（Demo）", systemImage: "message")
            }
            .navigationTitle("訊息")
        }
    }
}
