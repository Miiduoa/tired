import SwiftUI

// MARK: - 🎨 現代化加載視圖

struct AppLoadingView: View {
    let title: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: TTokens.spacingXL) {
            // 脈動加載圖標
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(TTokens.gradientPrimary.opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(index) * 20, height: 60 + CGFloat(index) * 20)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title)
                    .foregroundStyle(TTokens.gradientPrimary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 2)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(width: 120, height: 120)
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 🎨 現代化空狀態視圖

struct AppEmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: TTokens.spacingXL) {
            // 圖標（彈性動畫）
            ZStack {
                Circle()
                    .fill(TTokens.gradientPrimary.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .breathingCard(isActive: true)
                
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(TTokens.gradientPrimary)
                    .shadow(color: .tint.opacity(0.3), radius: 10, y: 5)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            // 文字
            VStack(spacing: TTokens.spacingSM) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.labelPrimary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .padding(TTokens.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - 🎨 現代化錯誤視圖

struct AppErrorView: View {
    let message: String
    let onRetry: () -> Void
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: TTokens.spacingXL) {
            // 錯誤圖標
            ZStack {
                Circle()
                    .fill(Color.danger.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.danger)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            // 錯誤訊息
            Text(message)
                .font(.headline)
                .foregroundStyle(Color.labelPrimary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            
            // 重試按鈕
            Button {
                HapticFeedback.medium()
                onRetry()
            } label: {
                HStack(spacing: TTokens.spacingSM) {
                    Image(systemName: "arrow.clockwise")
                    Text(L.s("action.retry"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 160, height: TTokens.touchTargetComfortable)
            }
            .fluidButton(gradient: TTokens.gradientPrimary)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .padding(TTokens.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}


