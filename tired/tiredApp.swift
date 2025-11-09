import SwiftUI
import FirebaseCore

@main
struct TiredApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var taskService = TaskService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    if taskService.userProfile?.currentTermId == nil {
                        OnboardingView()
                            .environmentObject(taskService)
                    } else {
                        MainTabView()
                            .environmentObject(taskService)
                    }
                } else {
                    AuthView()
                }
            }
            .environmentObject(authService)
            .onAppear {
                if let userId = authService.currentUserId {
                    taskService.initialize(userId: userId)
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

struct MainTabView: View {
    @EnvironmentObject var taskService: TaskService

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "calendar.circle.fill") }

            ThisWeekView()
                .tabItem { Label("本週", systemImage: "calendar") }

            BacklogView()
                .tabItem { Label("Backlog", systemImage: "tray.fill") }

            MeView()
                .tabItem { Label("我", systemImage: "person.circle.fill") }
        }
        .environmentObject(taskService)
        .tint(AppTheme.primaryColor)
    }
}

// Auth View
struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // 漸變背景
            LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GlassCard(padding: AppTheme.spacing4) {
                VStack(spacing: AppTheme.spacing3) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Tired")
                        .font(AppTheme.titleFont)

                    Text("大學生任務中樞")
                        .font(AppTheme.subheadline)
                        .foregroundColor(AppTheme.textSecondary)

                    VStack(spacing: AppTheme.spacing2) {
                        TextField("電子郵件", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("密碼", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: handleAuth) {
                        Text(isSignUp ? "註冊" : "登入")
                            .font(AppTheme.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                    .disabled(email.isEmpty || password.isEmpty)

                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "已有帳號？登入" : "沒有帳號？註冊")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(AppTheme.spacing3)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func handleAuth() {
        if isSignUp {
            authService.signUp(email: email, password: password) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            authService.signIn(email: email, password: password) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
