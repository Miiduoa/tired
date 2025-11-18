import SwiftUI
import FirebaseCore

@main
struct TiredApp: App {
    @StateObject private var authService = AuthService()

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
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
    }
}
