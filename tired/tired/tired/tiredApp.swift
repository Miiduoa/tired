import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct TiredApp: App {
    // connect app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authService = AuthService()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var recurringTaskService = RecurringTaskService.shared

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(networkMonitor)
                .withToastMessages()
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView("載入中...")
            } else {
                if authService.currentUser != nil {
                    MainTabView()
                        .environmentObject(authService)
                        .onAppear {
                            // 已登入用戶首次使用時顯示引導
                            if !hasSeenOnboarding {
                                showOnboarding = true
                            }
                        }
                        .fullScreenCover(isPresented: $showOnboarding) {
                            OnboardingView(showOnboarding: $showOnboarding)
                        }
                } else {
                    LoginView()
                        .environmentObject(authService)
                }
            }
        }
        .onOpenURL { url in
            // 處理 Google Sign-In 的 URL callback
            GIDSignIn.sharedInstance.handle(url)
        }
        .onAppear {
            themeManager.applyTheme()
            _Concurrency.Task {
                await NotificationService.shared.requestAuthorization()
            }
        }
        .onChange(of: themeManager.currentTheme) {
            themeManager.applyTheme()
        }
        .task(id: authService.currentUser?.uid) {
            if let userId = authService.currentUser?.uid {
                do {
                    try await RecurringTaskService.shared.generateDueInstances(userId: userId)
                } catch {
                    print("❌ Failed to generate recurring tasks: \(error)")
                }
            }
        }
    }
}
