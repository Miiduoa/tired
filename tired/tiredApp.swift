import SwiftUI
import FirebaseCore

@main
struct TiredApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    if appCoordinator.isLoading {
                        LoadingView(message: "初始化中...")
                    } else if !appCoordinator.isOnboardingComplete {
                        OnboardingView()
                            .environmentObject(appCoordinator)
                    } else {
                        TaskManagementMainView()
                            .environmentObject(appCoordinator)
                    }
                } else {
                    AuthView()
                }
            }
            .environmentObject(authService)
            .task {
                if let userId = authService.currentUser?.id {
                    await appCoordinator.initialize(userId: userId)
                }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseService.shared.configureIfNeeded()
        return true
    }
}

// MARK: - Task Management Main View
struct TaskManagementMainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)

            ThisWeekView()
                .tabItem {
                    Label("This Week", systemImage: "calendar")
                }
                .tag(1)

            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "tray.fill")
                }
                .tag(2)

            MeView()
                .tabItem {
                    Label("我", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
