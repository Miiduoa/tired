import SwiftUI

/// 深色模式增強組件
struct DarkModeAwareModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    let lightContent: AnyView
    let darkContent: AnyView
    
    func body(content: Content) -> some View {
        Group {
            if colorScheme == .dark {
                darkContent
            } else {
                lightContent
            }
        }
    }
}

extension View {
    /// 深淺色模式自適應內容
    func adaptiveContent<Light: View, Dark: View>(
        light: @escaping () -> Light,
        dark: @escaping () -> Dark
    ) -> some View {
        self.modifier(
            DarkModeAwareModifier(
                lightContent: AnyView(light()),
                darkContent: AnyView(dark())
            )
        )
    }
}

// MARK: - Adaptive Shadows

struct AdaptiveShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: colorScheme == .dark
                    ? Color.white.opacity(0.03)
                    : Color.black.opacity(0.1),
                radius: radius,
                x: x,
                y: y
            )
    }
}

extension View {
    /// 自適應陰影（深淺色模式）
    func adaptiveShadow(radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 2) -> some View {
        self.modifier(AdaptiveShadowModifier(radius: radius, x: x, y: y))
    }
}

// MARK: - Adaptive Borders

struct AdaptiveBorderModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let width: CGFloat
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.1),
                        lineWidth: width
                    )
            )
    }
}

extension View {
    /// 自適應邊框
    func adaptiveBorder(width: CGFloat = 1, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(AdaptiveBorderModifier(width: width, cornerRadius: cornerRadius))
    }
}

// MARK: - Glassmorphism Effect (Enhanced for Dark Mode)

struct EnhancedGlassmorphismModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 基礎模糊背景
                    if colorScheme == .dark {
                        Color.white.opacity(0.05)
                    } else {
                        Color.white.opacity(0.7)
                    }
                    
                    // 毛玻璃效果
                    if colorScheme == .dark {
                        .ultraThinMaterial
                    } else {
                        .regularMaterial
                    }
                }
                .cornerRadius(cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.2), Color.white.opacity(0.05)]
                                : [Color.white.opacity(0.8), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .adaptiveShadow()
    }
}

extension View {
    /// 增強的玻璃態效果（深淺色模式優化）
    func enhancedGlassmorphism(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(EnhancedGlassmorphismModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Adaptive Buttons

struct AdaptiveButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    let style: ButtonStyleType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Group {
                    switch style {
                    case .primary:
                        Color.accentColor
                    case .secondary:
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.05)
                    case .destructive:
                        Color.red
                    }
                }
            )
            .foregroundStyle(
                style == .primary || style == .destructive
                    ? Color.white
                    : Color.textPrimary
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
    
    enum ButtonStyleType {
        case primary, secondary, destructive
    }
}

extension View {
    func adaptivePrimaryButton() -> some View {
        self.buttonStyle(AdaptiveButtonStyle(style: .primary))
    }
    
    func adaptiveSecondaryButton() -> some View {
        self.buttonStyle(AdaptiveButtonStyle(style: .secondary))
    }
    
    func adaptiveDestructiveButton() -> some View {
        self.buttonStyle(AdaptiveButtonStyle(style: .destructive))
    }
}

// MARK: - Dark Mode Preview Helper

struct DarkModePreviewHelper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 淺色模式
            content
                .environment(\.colorScheme, .light)
                .frame(maxWidth: .infinity)
            
            // 深色模式
            content
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Contrast Enhancer

struct ContrastEnhancerModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    func body(content: Content) -> some View {
        content
            .brightness(
                reduceTransparency && colorScheme == .dark ? 0.05 : 0
            )
            .contrast(
                reduceTransparency ? 1.1 : 1.0
            )
    }
}

extension View {
    /// 增強對比度（提高可訪問性）
    func enhancedContrast() -> some View {
        self.modifier(ContrastEnhancerModifier())
    }
}

// MARK: - Example Usage Views

struct DarkModeExampleView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text("深色模式增強示例")
                .font(.title.bold())
                .foregroundStyle(.textPrimary)
            
            // 玻璃態卡片
            VStack(alignment: .leading, spacing: 12) {
                Text("增強玻璃態效果")
                    .font(.headline)
                Text("這是一個自動適配深淺色模式的玻璃態卡片")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .enhancedGlassmorphism()
            
            // 自適應按鈕
            VStack(spacing: 12) {
                Button("主要按鈕") {}
                    .adaptivePrimaryButton()
                
                Button("次要按鈕") {}
                    .adaptiveSecondaryButton()
                
                Button("危險按鈕") {}
                    .adaptiveDestructiveButton()
            }
            
            // 自適應卡片
            VStack(alignment: .leading, spacing: 8) {
                Text("自適應卡片")
                    .font(.headline)
                Text("帶有自動陰影和邊框")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveCard()
            
            Spacer()
        }
        .padding()
        .adaptiveBackground()
    }
}

// MARK: - Preview

#Preview("Light & Dark") {
    DarkModePreviewHelper {
        DarkModeExampleView()
    }
}

#Preview("Dark Mode Only") {
    DarkModeExampleView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode Only") {
    DarkModeExampleView()
        .preferredColorScheme(.light)
}

