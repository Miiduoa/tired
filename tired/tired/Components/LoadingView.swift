import SwiftUI

/// 載入視圖組件
struct LoadingView: View {
    let message: String
    let style: LoadingStyle
    
    init(message: String = "載入中...", style: LoadingStyle = .standard) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch style {
            case .standard:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.accentColor)
            case .dots:
                DotsLoadingView()
            case .spinner:
                SpinnerView()
            case .pulse:
                PulseView()
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

enum LoadingStyle {
    case standard
    case dots
    case spinner
    case pulse
}

// MARK: - Dots Loading

struct DotsLoadingView: View {
    @State private var animationStates = [false, false, false]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animationStates[index] ? 1.0 : 0.5)
                    .opacity(animationStates[index] ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationStates[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                    animationStates[index] = true
                }
            }
        }
    }
}

// MARK: - Spinner Loading

struct SpinnerView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 40, height: 40)
            .rotationEffect(Angle(degrees: rotation))
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Pulse Loading

struct PulseView: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 40, height: 40)
            .scaleEffect(scale)
            .opacity(2.0 - scale)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    scale = 2.0
                }
            }
    }
}

// MARK: - Skeleton Loading

struct SkeletonView: View {
    @State private var shimmerOffset: CGFloat = -1
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.secondary.opacity(0.1),
                        Color.secondary.opacity(0.2),
                        Color.secondary.opacity(0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.45),
                                .init(color: .white, location: 0.55),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: shimmerOffset * UIScreen.main.bounds.width)
                    )
            )
            .cornerRadius(cornerRadius)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 2
                }
            }
    }
}

// MARK: - Preview

#Preview("Standard") {
    LoadingView(message: "載入數據中...", style: .standard)
}

#Preview("Dots") {
    LoadingView(message: "處理中...", style: .dots)
}

#Preview("Spinner") {
    LoadingView(message: "請稍候...", style: .spinner)
}

#Preview("Pulse") {
    LoadingView(message: "同步中...", style: .pulse)
}

#Preview("Skeleton") {
    VStack(spacing: 16) {
        SkeletonView(height: 60, cornerRadius: 12)
        SkeletonView(height: 40, cornerRadius: 8)
        SkeletonView(height: 40, cornerRadius: 8)
        SkeletonView(height: 20, cornerRadius: 4)
    }
    .padding()
}

