import SwiftUI
import UserNotifications

// MARK: - Notification Settings View

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var enableNotifications = true
    @State private var taskReminders = true
    @State private var eventReminders = true
    @State private var organizationUpdates = true
    @State private var showingSaved = false
    
    @State private var systemAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSettingsAlert = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Toggle("啟用通知", isOn: $enableNotifications)
                    .onChange(of: enableNotifications) { _, newValue in
                        handleNotificationToggle(enabled: newValue)
                    }
            } footer: {
                Text("管理此應用的系統級通知權限。")
            }

            Section {
                Toggle("任務提醒", isOn: $taskReminders)
                Toggle("活動提醒", isOn: $eventReminders)
                Toggle("組織動態", isOn: $organizationUpdates)
            } header: {
                Text("通知類型")
            } footer: {
                if showingSaved {
                    Text("已儲存")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .disabled(!enableNotifications)
        }
        .navigationTitle("通知設置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkSystemNotificationStatus()
            loadSettings()
        }
        .onChange(of: [taskReminders, eventReminders, organizationUpdates]) { _, _ in
            saveSettings()
        }
        .alert("開啟通知", isPresented: $showSettingsAlert) {
            Button("前往設置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {
                // User chose not to go to settings, revert the toggle
                enableNotifications = false
            }
        } message: {
            Text("請在系統設置中允許 'Tired' App 發送通知。")
        }
    }

    private func checkSystemNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.systemAuthStatus = settings.authorizationStatus
                // Sync the toggle with the actual system status
                self.enableNotifications = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func handleNotificationToggle(enabled: Bool) {
        if enabled {
            switch systemAuthStatus {
            case .notDetermined:
                // Request permission for the first time
                Task {
                    let granted = await NotificationService.shared.requestAuthorization()
                    if granted {
                        await MainActor.run {
                            self.enableNotifications = true
                            self.systemAuthStatus = .authorized
                            saveSettings()
                        }
                    } else {
                        await MainActor.run {
                            self.enableNotifications = false
                        }
                    }
                }
            case .denied:
                // Guide user to settings
                showSettingsAlert = true
            case .authorized, .provisional, .ephemeral:
                // Already authorized, just save the preference
                saveSettings()
            @unknown default:
                break
            }
        } else {
            // User is disabling notifications in-app
            saveSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            // `enableNotifications` is now primarily driven by system status,
            // but we can still load the sub-toggles.
            taskReminders = profile.taskReminders ?? true
            eventReminders = profile.eventReminders ?? true
            organizationUpdates = profile.organizationUpdates ?? true
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        _Concurrency.Task {
            do {
                try await userService.updateNotificationSettings(
                    userId: userId,
                    notificationsEnabled: enableNotifications,
                    taskReminders: taskReminders,
                    eventReminders: eventReminders,
                    organizationUpdates: organizationUpdates
                )
                await MainActor.run {
                    withAnimation {
                        showingSaved = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSaved = false
                        }
                    }
                }
            } catch {
                print("❌ Error saving notification settings: \(error)")
            }
        }
    }
}
