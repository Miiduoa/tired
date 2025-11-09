import SwiftUI

/// 玻璃效果卡片組件
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = AppTheme.spacing2
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium

    init(padding: CGFloat = AppTheme.spacing2,
         cornerRadius: CGFloat = AppTheme.cornerRadiusMedium,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(AppTheme.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 2)
    }
}

/// 帶漸變邊框的玻璃卡片
struct GlassCardWithGradientBorder<Content: View>: View {
    let content: Content
    var padding: CGFloat = AppTheme.spacing2
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var gradientColors: [Color] = [AppTheme.primaryColor, AppTheme.secondaryColor]

    init(padding: CGFloat = AppTheme.spacing2,
         cornerRadius: CGFloat = AppTheme.cornerRadiusMedium,
         gradientColors: [Color] = [AppTheme.primaryColor, AppTheme.secondaryColor],
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.gradientColors = gradientColors
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(AppTheme.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: gradientColors[0].opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

/// 浮動動作按鈕（FAB）- 玻璃效果
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var backgroundColor: Color = AppTheme.primaryColor

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [backgroundColor, backgroundColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: backgroundColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

/// 模糊背景
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Previews

struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("玻璃卡片")
                            .font(AppTheme.headline)
                        Text("這是一個帶有毛玻璃效果的卡片組件")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                GlassCardWithGradientBorder {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("漸變邊框卡片")
                            .font(AppTheme.headline)
                        Text("帶有漸變邊框的玻璃卡片")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                FloatingActionButton(icon: "plus") {
                    print("FAB tapped")
                }
            }
            .padding()
        }
    }
}
