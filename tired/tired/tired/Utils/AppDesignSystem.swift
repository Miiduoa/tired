import SwiftUI

// MARK: - Global Design System Definitions

struct AppDesignSystem {
    // Colors - Now using the new custom extension
    static let primaryBackground = Color.appPrimaryBackground
    static let secondaryBackground = Color.appSecondaryBackground
    static let accentColor = Color.appAccent
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.00, green: 0.77, blue: 0.80),
            Color(red: 0.05, green: 0.62, blue: 0.77)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let surfaceGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.12),
            Color.white.opacity(0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let glassOverlay = Color.appCardBorder.opacity(0.1) // Use a subtle border color for overlay
    static let shadow = Color.black.opacity(0.1)

    // Corner Radius - 簡化圓角設計
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16

    // Padding - 調整為更實用的間距
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // Fonts - 簡化字體層次
    static let titleFont = Font.system(size: 24, weight: .bold)
    static let headlineFont = Font.system(size: 18, weight: .semibold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
}

// MARK: - View Modifiers for Design System

/// 標準卡片背景風格 (Clean & Modern)
struct StandardCardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium
    var padding: CGFloat = AppDesignSystem.paddingMedium
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.appSecondaryBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: AppDesignSystem.shadow, radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appCardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    /// 應用標準卡片風格
    func standardCard(cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium, padding: CGFloat = AppDesignSystem.paddingMedium) -> some View {
        self.modifier(StandardCardStyle(cornerRadius: cornerRadius, padding: padding))
    }
}

/// 主要按鈕風格 (Solid High Contrast)
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppDesignSystem.headlineFont)
            .foregroundColor(.white)
            .padding(.vertical, AppDesignSystem.paddingMedium)
            .padding(.horizontal, AppDesignSystem.paddingLarge)
            .frame(maxWidth: .infinity)
            .background(
                isEnabled ? AppDesignSystem.accentColor : Color.gray.opacity(0.3)
            )
            .cornerRadius(AppDesignSystem.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 次要按鈕風格 (Bordered / Ghost)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppDesignSystem.bodyFont.weight(.medium))
            .foregroundColor(AppDesignSystem.accentColor)
            .padding(.vertical, AppDesignSystem.paddingMedium - 2)
            .padding(.horizontal, AppDesignSystem.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                    .stroke(AppDesignSystem.accentColor.opacity(0.5), lineWidth: 1)
                    .background(Color.appSecondaryBackground.opacity(0.5))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 標準輸入框風格
struct StandardTextFieldStyle: TextFieldStyle {
    var icon: String? = nil
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            configuration
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Custom Colors (Hardcoded for direct use)

extension Color {
    static var appPrimaryBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0) : // Dark mode deep gray
                UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1.0)   // Light mode light gray
        })
    }
    static var appSecondaryBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0) : // Dark mode slightly lighter gray
                UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)   // Light mode white
        })
    }
    static var appAccent: Color {
        Color(UIColor(red: 0.00, green: 0.77, blue: 0.80, alpha: 1.0)) // Vibrant Teal
    }
    static var appCardBorder: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(red: 0.28, green: 0.28, blue: 0.29, alpha: 0.5) : // Dark mode subtle gray
                UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 0.5)   // Light mode subtle gray
        })
    }
    
    // 別名：為了兼容性
    static var appBackground: Color {
        appPrimaryBackground
    }
}

// MARK: - Background

/// 層疊式背景，帶有柔和色塊與漸層，營造更現代的氛圍
@available(iOS 17.0, *)
struct LayeredBackground: View {
    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()
            
            // 簡化背景，移除過多的模糊圓圈，改用極簡的漸層
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glassmorphic Components

@available(iOS 15.0, *)
private struct GlassmorphicCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var material: Material
    var shadowOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppDesignSystem.glassOverlay, lineWidth: 1)
            )
            .shadow(color: AppDesignSystem.shadow.opacity(shadowOpacity), radius: 10, x: 0, y: 4)
    }
}

@available(iOS 15.0, *)
extension View {
    /// Adds a subtle glass-like background with a soft border and shadow.
    func glassmorphicCard(
        cornerRadius: CGFloat = AppDesignSystem.cornerRadiusLarge,
        material: Material = .ultraThinMaterial,
        shadowOpacity: Double = 0.25
    ) -> some View {
        modifier(GlassmorphicCardModifier(cornerRadius: cornerRadius, material: material, shadowOpacity: shadowOpacity))
    }
}

@available(iOS 15.0, *)
struct GlassmorphicButtonStyle: ButtonStyle {
    var material: Material = .ultraThinMaterial
    var cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium
    var textColor: Color = AppDesignSystem.accentColor
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppDesignSystem.bodyFont.weight(.medium))
            .foregroundColor(textColor)
            .padding(.vertical, AppDesignSystem.paddingSmall)
            .padding(.horizontal, AppDesignSystem.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppDesignSystem.glassOverlay, lineWidth: 1)
            )
            .shadow(color: AppDesignSystem.shadow.opacity(0.2), radius: 8, x: 0, y: 3)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
