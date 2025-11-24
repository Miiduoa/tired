import SwiftUI

// MARK: - Global Design System Definitions

struct AppDesignSystem {
    // Colors - Now using the new custom extension
    static let primaryBackground = Color.appPrimaryBackground
    static let secondaryBackground = Color.appSecondaryBackground
    static let accentColor = Color.appAccent
    static let glassOverlay = Color.appCardBorder.opacity(0.15) // Use a subtle border color for overlay

    // Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24

    // Padding
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // Fonts (can add custom fonts or specific system styles)
    static let titleFont = Font.system(size: 28, weight: .bold)
    static let headlineFont = Font.system(size: 20, weight: .semibold)
    static let bodyFont = Font.system(size: 17, weight: .regular)
    static let captionFont = Font.system(size: 13, weight: .regular)
}

// MARK: - View Modifiers for Glassmorphism

/// 玻璃擬態背景修飾符
struct GlassmorphicBackground: ViewModifier {
    var cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium
    var material: Material = .ultraThinMaterial // Default material for glass effect, more pronounced

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material) // Base material effect
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5) // Soft shadow
                    .overlay( // Optional: light border or highlight for depth
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppDesignSystem.glassOverlay, lineWidth: 1)
                    )
            )
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// 應用玻璃擬態背景風格
    func glassmorphicCard(cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium, material: Material = .ultraThinMaterial) -> some View {
        self.modifier(GlassmorphicBackground(cornerRadius: cornerRadius, material: material))
    }
}

/// 玻璃擬態按鈕風格
struct GlassmorphicButtonStyle: ButtonStyle {
    var material: Material = .ultraThinMaterial
    var cornerRadius: CGFloat = AppDesignSystem.cornerRadiusMedium
    var textColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppDesignSystem.bodyFont.weight(.semibold))
            .foregroundColor(textColor)
            .padding(.vertical, AppDesignSystem.paddingMedium)
            .padding(.horizontal, AppDesignSystem.paddingLarge)
            .glassmorphicCard(cornerRadius: cornerRadius, material: material) // Reusing the background modifier
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// 玻璃擬態輸入框風格
struct FrostedTextFieldStyle: TextFieldStyle {
    var material: Material = .ultraThinMaterial
    var cornerRadius: CGFloat = AppDesignSystem.cornerRadiusSmall

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppDesignSystem.bodyFont)
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: cornerRadius, material: material) // Reusing the background modifier
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
}
