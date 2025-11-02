import SwiftUI
import Combine

/// 主題管理器
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .system {
        didSet {
            saveTheme()
            applyTheme()
        }
    }
    
    @Published var preferredColorScheme: ColorScheme? = nil
    
    private init() {
        loadTheme()
        applyTheme()
    }
    
    // MARK: - Theme Selection
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
    
    private func applyTheme() {
        switch currentTheme {
        case .light:
            preferredColorScheme = .light
        case .dark:
            preferredColorScheme = .dark
        case .system:
            preferredColorScheme = nil
        }
    }
    
    // MARK: - Persistence
    
    private let themeKey = "app_theme"
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }
    
    private func loadTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
}

/// 應用主題選項
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "淺色模式"
        case .dark: return "深色模式"
        case .system: return "跟隨系統"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Theme Colors Extension

extension Color {
    // MARK: - Background Colors
    
    /// 主背景色（自動適配深淺色模式）
    static var bg: Color {
        Color("Background", bundle: nil) ?? Color(uiColor: .systemBackground)
    }
    
    /// 次級背景色
    static var bg2: Color {
        Color("SecondaryBackground", bundle: nil) ?? Color(uiColor: .secondarySystemBackground)
    }
    
    /// 卡片背景色
    static var cardBackground: Color {
        Color("CardBackground", bundle: nil) ?? Color(uiColor: .systemGroupedBackground)
    }
    
    // MARK: - Text Colors
    
    /// 主要文字顏色
    static var textPrimary: Color {
        Color("TextPrimary", bundle: nil) ?? Color(uiColor: .label)
    }
    
    /// 次要文字顏色
    static var textSecondary: Color {
        Color("TextSecondary", bundle: nil) ?? Color(uiColor: .secondaryLabel)
    }
    
    /// 提示文字顏色
    static var textTertiary: Color {
        Color("TextTertiary", bundle: nil) ?? Color(uiColor: .tertiaryLabel)
    }
    
    // MARK: - Semantic Colors
    
    /// 強調色（自動適配）
    static var accent: Color {
        Color.accentColor
    }
    
    /// 成功色
    static var success: Color {
        Color("Success", bundle: nil) ?? Color.green
    }
    
    /// 警告色
    static var warning: Color {
        Color("Warning", bundle: nil) ?? Color.orange
    }
    
    /// 錯誤色
    static var error: Color {
        Color("Error", bundle: nil) ?? Color.red
    }
    
    /// 資訊色
    static var info: Color {
        Color("Info", bundle: nil) ?? Color.blue
    }
    
    // MARK: - Border & Separator
    
    /// 分隔線顏色
    static var separator: Color {
        Color("Separator", bundle: nil) ?? Color(uiColor: .separator)
    }
    
    /// 邊框顏色
    static var border: Color {
        Color("Border", bundle: nil) ?? Color(uiColor: .separator)
    }
    
    // MARK: - Dark Mode Specific
    
    /// 深色模式下的疊加層
    static func overlayDark(opacity: Double = 0.05) -> Color {
        Color.white.opacity(opacity)
    }
    
    /// 淺色模式下的疊加層
    static func overlayLight(opacity: Double = 0.05) -> Color {
        Color.black.opacity(opacity)
    }
    
    /// 自動適配的疊加層
    @ViewBuilder
    static func adaptiveOverlay(opacity: Double = 0.05) -> some ShapeStyle {
        Color.primary.opacity(opacity)
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// 套用主題
    func themed() -> some View {
        self
            .environment(\.themeManager, ThemeManager.shared)
            .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
    }
    
    /// 自適應背景色
    func adaptiveBackground() -> some View {
        self.background(Color.bg.ignoresSafeArea())
    }
    
    /// 卡片樣式（深淺色模式自適應）
    func adaptiveCard(padding: CGFloat = 16, cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.setTheme(theme)
                        }
                    } label: {
                        HStack {
                            Image(systemName: theme.icon)
                                .font(.title3)
                                .foregroundStyle(themeManager.currentTheme == theme ? .accent : .secondary)
                                .frame(width: 32)
                            
                            Text(theme.displayName)
                                .foregroundStyle(themeManager.currentTheme == theme ? .primary : .secondary)
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("外觀設定")
            } footer: {
                Text("選擇應用程式的外觀主題。跟隨系統選項將根據您的設備設定自動切換。")
            }
            
            Section {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.orange)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 40)
                        .cornerRadius(8)
                    
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 8)
            } header: {
                Text("預覽")
            }
        }
        .navigationTitle("主題設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
}

