import SwiftUI

// MARK: - Glass Card with iOS-style Blur Effect
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var cornerRadius: CGFloat
    var material: Material
    var shadowRadius: CGFloat
    var borderColor: Color
    var borderWidth: CGFloat

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        material: Material = .regular,
        shadowRadius: CGFloat = 8,
        borderColor: Color = Color.white.opacity(0.2),
        borderWidth: CGFloat = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
        self.shadowRadius = shadowRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Glass blur effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(material.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(borderColor, lineWidth: borderWidth)
                        )

                    // Additional blur for enhanced glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.05))
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 4)
    }

    // MARK: - Material Types
    enum Material {
        case thin
        case regular
        case thick
        case prominent

        var background: some ShapeStyle {
            switch self {
            case .thin:
                return .ultraThinMaterial
            case .regular:
                return .regularMaterial
            case .thick:
                return .thickMaterial
            case .prominent:
                return .ultraThickMaterial
            }
        }
    }
}

// MARK: - Glass Button
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: Style

    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style.borderColor, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    enum Style {
        case primary
        case secondary
        case destructive
        case ghost

        var background: some ShapeStyle {
            switch self {
            case .primary:
                return .regularMaterial
            case .secondary:
                return .thinMaterial
            case .destructive:
                return .regularMaterial
            case .ghost:
                return .ultraThinMaterial
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                return .blue
            case .secondary:
                return .primary
            case .destructive:
                return .red
            case .ghost:
                return .secondary
            }
        }

        var borderColor: Color {
            switch self {
            case .primary:
                return Color.blue.opacity(0.3)
            case .secondary:
                return Color.gray.opacity(0.2)
            case .destructive:
                return Color.red.opacity(0.3)
            case .ghost:
                return Color.clear
            }
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass Section Header
struct GlassSectionHeader: View {
    let title: String
    let icon: String?
    let action: (() -> Void)?
    let actionTitle: String?

    init(
        _ title: String,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Glass Badge
struct GlassBadge: View {
    let text: String
    var color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview
struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background gradient for preview
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Glass Card Example")
                            .font(.headline)
                        Text("This is a glass card with iOS-style blur effect")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                GlassButton("Primary Button", icon: "plus.circle.fill", style: .primary) {
                    print("Tapped")
                }

                GlassButton("Secondary Button", style: .secondary) {
                    print("Tapped")
                }

                GlassBadge(text: "P0", color: .red, icon: "flag.fill")
            }
            .padding()
        }
    }
}
