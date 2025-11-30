import SwiftUI

// MARK: - Appearance Settings View

@available(iOS 17.0, *)
struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthService
    
    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Picker("主題", selection: $themeManager.currentTheme) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: themeManager.currentTheme) { _, newTheme in
                    // Also save the preference to the user's backend profile
                    saveThemePreference(theme: newTheme)
                }
            } header: {
                Text("外觀主題")
            }
        }
        .navigationTitle("外觀")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sync the theme manager with the user's profile setting if it exists
            if let profileTheme = authService.userProfile?.theme,
               let theme = Theme(rawValue: profileTheme),
               theme != themeManager.currentTheme {
                themeManager.currentTheme = theme
            }
        }
    }
    
    private func saveThemePreference(theme: Theme) {
        guard let userId = authService.userProfile?.id else { return }

        _Concurrency.Task {
            do {
                try await userService.updateAppearanceSettings(userId: userId, theme: theme.rawValue)
                // The visual feedback is now handled by the theme changing instantly.
                // A toast could be added here if explicit "Saved" confirmation is desired.
            } catch {
                print("❌ Error saving appearance settings to user profile: \(error)")
            }
        }
    }
}
