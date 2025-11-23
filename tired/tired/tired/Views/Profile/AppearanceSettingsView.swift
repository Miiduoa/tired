import SwiftUI

// MARK: - Appearance Settings View

@available(iOS 17.0, *)
struct AppearanceSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTheme = "auto"
    @State private var showingSaved = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Picker("主題", selection: $selectedTheme) {
                    Text("跟隨系統").tag("auto")
                    Text("淺色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
                .onChange(of: selectedTheme) { _, _ in
                    saveSettings()
                }
            } header: {
                Text("外觀主題")
            } footer: {
                if showingSaved {
                    Text("已儲存")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("外觀")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            selectedTheme = profile.theme ?? "auto"
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        _Concurrency.Task {
            do {
                try await userService.updateAppearanceSettings(userId: userId, theme: selectedTheme)
                await MainActor.run {
                    showingSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving appearance settings: \(error)")
            }
        }
    }
}
