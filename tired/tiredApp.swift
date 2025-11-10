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
            .alert("偵測到中斷的專注模式", isPresented: $appCoordinator.showFocusRecovery) {
                Button("繼續專注") {
                    appCoordinator.restoreFocusSession()
                }
                Button("放棄", role: .destructive) {
                    Task {
                        await appCoordinator.discardFocusSession()
                    }
                }
            } message: {
                if let task = appCoordinator.crashedFocusTask,
                   let state = appCoordinator.crashedFocusState {
                    let elapsedMin = Int((Date().timeIntervalSince(state.sessionStart)) / 60)
                    Text("任務「\(task.title)」的專注模式在 \(elapsedMin) 分鐘前中斷。是否要繼續？")
                } else {
                    Text("是否要恢復先前的專注模式？")
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
    @EnvironmentObject var appCoordinator: AppCoordinator
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
        .withToast()
        .fullScreenCover(isPresented: $appCoordinator.shouldRestoreFocus) {
            if let task = appCoordinator.crashedFocusTask {
                FocusModeView(task: task)
                    .onDisappear {
                        appCoordinator.focusRestorationCompleted()
                    }
            }
        }
        .sheet(isPresented: $appCoordinator.showTermCleanup) {
            TermCleanupView()
                .environmentObject(appCoordinator)
        }
    }
}
