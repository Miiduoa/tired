import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TiredApp: App {
    // connect app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authService = AuthService()

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .withToastMessages()
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView("加载中...")
            } else if authService.currentUser != nil {
                MainTabView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .onOpenURL { url in
            // 處理 Google Sign-In 的 URL callback
            GIDSignIn.sharedInstance.handle(url)
        }
    }
}
