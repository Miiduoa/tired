import SwiftUI

@available(iOS 17.0, *)
struct EmptyStateView: View {
    var icon: String = "checkmark.circle"
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            // 動畫圖標
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(iconBackgroundColor.gradient)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.bottom, 8)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(message)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // 主要操作按鈕
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppDesignSystem.accentGradient)
                    .cornerRadius(25)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 8)
            }
            
            // 次要操作按鈕
            if let secondaryActionTitle = secondaryActionTitle, let secondaryAction = secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppDesignSystem.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesignSystem.paddingLarge * 1.5)
        .glassmorphicCard()
        .onAppear {
            isAnimating = true
        }
    }
    
    private var iconBackgroundColor: Color {
        switch icon {
        case let i where i.contains("sun"):
            return .orange
        case let i where i.contains("tray"):
            return .purple
        case let i where i.contains("calendar"):
            return .blue
        case let i where i.contains("checkmark"):
            return .green
        case let i where i.contains("magnifyingglass"):
            return .gray
        default:
            return AppDesignSystem.accentColor
        }
    }
}

// MARK: - 慶祝動畫視圖（用於任務完成時）
@available(iOS 17.0, *)
struct CelebrationView: View {
    let achievement: TaskAchievement?
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        onDismiss()
                    }
                }
            
            // 慶祝卡片
            VStack(spacing: 24) {
                // 成就圖標
                if let achievement = achievement {
                    Text(achievement.icon)
                        .font(.system(size: 72))
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1.0 : 0.0)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1.0 : 0.0)
                }
                
                // 標題
                VStack(spacing: 8) {
                    Text(achievement?.title ?? "太棒了！")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(achievement?.description ?? "任務已完成")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
                
                // 關閉按鈕
                Button {
                    withAnimation(.spring()) {
                        onDismiss()
                    }
                } label: {
                    Text("繼續")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(AppDesignSystem.accentGradient)
                        .cornerRadius(25)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .scaleEffect(showContent ? 1.0 : 0.8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Material.regularMaterial)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(32)
            .scaleEffect(showContent ? 1.0 : 0.9)
            
            // 簡單的慶祝效果
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

// MARK: - 簡單的五彩紙屑效果
@available(iOS 17.0, *)
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        particles = (0..<30).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 6...12),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                targetPosition: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: size.height + 50
                ),
                opacity: 1.0
            )
        }
    }
    
    private func animateParticles() {
        for index in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1.5...2.5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: duration)) {
                    particles[index].position = particles[index].targetPosition
                    particles[index].opacity = 0
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let targetPosition: CGPoint
    var opacity: Double
}
