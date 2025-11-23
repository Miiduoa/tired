import SwiftUI

// MARK: - Notification Settings View

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var enableNotifications = true
    @State private var taskReminders = true
    @State private var eventReminders = true
    @State private var organizationUpdates = true
    @State private var showingSaved = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Toggle("啟用通知", isOn: $enableNotifications)
                    .onChange(of: enableNotifications) { _, _ in saveSettings() }
            }

            Section {
                Toggle("任務提醒", isOn: $taskReminders)
                    .onChange(of: taskReminders) { _, _ in saveSettings() }
                Toggle("活動提醒", isOn: $eventReminders)
                    .onChange(of: eventReminders) { _, _ in saveSettings() }
                Toggle("組織動態", isOn: $organizationUpdates)
                    .onChange(of: organizationUpdates) { _, _ in saveSettings() }
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
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            enableNotifications = profile.notificationsEnabled ?? true
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
                    showingSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving notification settings: \(error)")
            }
        }
    }
}
