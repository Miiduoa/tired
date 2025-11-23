import SwiftUI

// MARK: - Time Management Settings View

@available(iOS 17.0, *)
struct TimeManagementSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var weeklyCapacityHours: Double = 12.0
    @State private var dailyCapacityHours: Double = 8.0
    @State private var isSaving = false
    @State private var showingSaved = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每週時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", weeklyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $weeklyCapacityHours, in: 1...40, step: 1)
                        .onChange(of: weeklyCapacityHours) { _, _ in
                            saveSettings()
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", dailyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $dailyCapacityHours, in: 1...16, step: 1)
                        .onChange(of: dailyCapacityHours) { _, _ in
                            saveSettings()
                        }
                }
            } header: {
                Text("時間容量")
            } footer: {
                HStack {
                    Text("用於自動排程時計算每週和每日的任務量")
                    Spacer()
                    if showingSaved {
                        Text("已儲存")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("時間管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            weeklyCapacityHours = Double(profile.weeklyCapacityMinutes ?? 720) / 60.0
            dailyCapacityHours = Double(profile.dailyCapacityMinutes ?? 480) / 60.0
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        isSaving = true
        _Concurrency.Task {
            do {
                try await userService.updateTimeManagementSettings(
                    userId: userId,
                    weeklyCapacityMinutes: Int(weeklyCapacityHours * 60),
                    dailyCapacityMinutes: Int(dailyCapacityHours * 60)
                )
                await MainActor.run {
                    showingSaved = true
                    isSaving = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving time settings: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
