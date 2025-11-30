import Foundation
import SwiftUI
import Combine
import UIKit

enum Theme: String, CaseIterable, Identifiable {
    case system = "auto"
    case light = "light"
    case dark = "dark"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "跟隨系統"
        case .light:
            return "淺色"
        case .dark:
            return "深色"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme {
        didSet {
            // Save the new theme to UserDefaults
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
            applyTheme()
        }
    }

    init() {
        // Load the saved theme from UserDefaults or default to system
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "auto"
        self.currentTheme = Theme(rawValue: savedTheme) ?? .system
    }

    func applyTheme() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        let windows = scene.windows
        
        var userInterfaceStyle: UIUserInterfaceStyle = .unspecified
        switch currentTheme {
        case .light:
            userInterfaceStyle = .light
        case .dark:
            userInterfaceStyle = .dark
        case .system:
            userInterfaceStyle = .unspecified
        }
        
        for window in windows {
            window.overrideUserInterfaceStyle = userInterfaceStyle
        }
    }
}
