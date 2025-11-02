import SwiftUI

// MARK: - 🎨 現代化社交互動組件（心理學優化）

/// 情感化按讚按鈕（Like Button with Emotion）
struct EmotionalLikeButton: View {
    @Binding var isLiked: Bool
    @Binding var count: Int
    @State private var showBurst = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isLiked.toggle()
                count += isLiked ? 1 : -1
                scale = isLiked ? 1.3 : 1.0
            }
            if isLiked {
                showBurst = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showBurst = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isLiked ? .red.gradient : .secondary)
                        .scaleEffect(scale)
                    
                    if showBurst {
                        ParticleBurst(color: .red)
                    }
                }
                .frame(width: 28, height: 28)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isLiked ? .red : .secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isLiked ? Color.red.opacity(0.1) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .onChange(of: scale) { _, _ in
            if scale > 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
        }
    }
}

/// 評論氣泡按鈕（Comment Bubble）
struct CommentBubbleButton: View {
    let count: Int
    let action: () -> Void
    @State private var bounce = false
    
    var body: some View {
        Button(action: {
            bounce = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounce = false
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.neutralLight.opacity(0.5), in: Capsule())
            .scaleEffect(bounce ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bounce)
        }
        .buttonStyle(.plain)
    }
}

/// 分享按鈕（Share with Ripple Effect）
struct ShareButton: View {
    let action: () -> Void
    @State private var showRipple = false
    
    var body: some View {
        Button(action: {
            showRipple = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRipple = false
            }
        }) {
            ZStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                if showRipple {
                    Circle()
                        .stroke(Color.tint, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .scaleEffect(showRipple ? 2 : 1)
                        .opacity(showRipple ? 0 : 1)
                        .animation(.easeOut(duration: 0.5), value: showRipple)
                }
            }
            .frame(width: 28, height: 28)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 🎴 現代化卡片樣式（視覺層級優化）

/// 英雄卡片（Hero Card - 吸引眼球的主要內容）
struct HeroCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let gradient: LinearGradient
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingLG) {
            // 標題區（漸層背景）
            VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TTokens.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .fill(gradient)
            }
            
            // 內容區
            content
                .padding(.horizontal, TTokens.spacingLG)
                .padding(.bottom, TTokens.spacingLG)
        }
        .background {
            RoundedRectangle(cornerRadius: TTokens.radiusXL, style: .continuous)
                .fill(Color.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TTokens.radiusXL, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: TTokens.shadowLevel3.color, radius: TTokens.shadowLevel3.radius, y: TTokens.shadowLevel3.y)
    }
}

/// 玻璃形態卡片（Glassmorphic Card - iOS 風格）
struct GlassmorphicCard<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(TTokens.spacingLG)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                        .fill(tint.opacity(0.05))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

/// 情境卡片（Contextual Card - 根據狀態變化）
struct ContextualCard<Content: View>: View {
    enum CardType {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return .tint
            case .success: return .success
            case .warning: return .warn
            case .error: return .danger
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    let type: CardType
    let title: String
    let message: String?
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .top, spacing: TTokens.spacingMD) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(type.color)
            
            VStack(alignment: .leading, spacing: TTokens.spacingSM) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.labelPrimary)
                
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                content
            }
            
            Spacer(minLength: 0)
        }
        .padding(TTokens.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                .fill(type.color.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - 🎯 互動反饋組件（即時反饋增強）

/// 觸覺反饋工具
struct HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

/// 加載佔位符（Skeleton with Shimmer）
struct SkeletonView: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = TTokens.radiusSM) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.neutralLight)
            .frame(height: height)
            .shimmer()
    }
}

/// 漸層骨架卡片（Modern Skeleton Card）
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack(spacing: TTokens.spacingMD) {
                Circle()
                    .fill(Color.neutralLight)
                    .frame(width: 44, height: 44)
                    .shimmer()
                
                VStack(alignment: .leading, spacing: TTokens.spacingSM) {
                    SkeletonView(height: 14, cornerRadius: TTokens.radiusXS)
                        .frame(width: 120)
                    SkeletonView(height: 12, cornerRadius: TTokens.radiusXS)
                        .frame(width: 80)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: TTokens.spacingSM) {
                SkeletonView(height: 12)
                SkeletonView(height: 12)
                SkeletonView(height: 12)
                    .frame(width: 200)
            }
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}

// MARK: - 🎨 視覺增強組件

/// 標籤徽章（Tag Badge）
struct TagBadge: View {
    let text: String
    let color: Color
    let icon: String?
    
    init(_ text: String, color: Color = .tint, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

/// 頭像環（Avatar Ring）
struct AvatarRing: View {
    let imageURL: URL?
    let size: CGFloat
    let ringColor: Color
    let ringWidth: CGFloat
    
    init(imageURL: URL? = nil, size: CGFloat = 44, ringColor: Color = .tint, ringWidth: CGFloat = 2) {
        self.imageURL = imageURL
        self.size = size
        self.ringColor = ringColor
        self.ringWidth = ringWidth
    }
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: ringWidth
                )
                .frame(width: size, height: size)
            
            Circle()
                .fill(Color.neutralLight)
                .frame(width: size - ringWidth * 2, height: size - ringWidth * 2)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
        }
        .shadow(color: ringColor.opacity(0.3), radius: 8, y: 4)
    }
}

/// 進度環（Progress Ring）
struct ProgressRing: View {
    let progress: Double // 0.0 ~ 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    let gradient: LinearGradient
    
    init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 80, gradient: LinearGradient = TTokens.gradientPrimary) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.gradient = gradient
    }
    
    var body: some View {
        ZStack {
            // 背景圓環
            Circle()
                .stroke(Color.neutralLight, lineWidth: lineWidth)
            
            // 進度圓環
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            
            // 中心文字
            Text("\(Int(progress * 100))%")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.labelPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 🌟 背景效果組件

/// 浮動粒子背景（Floating Particles - 增加動感）
struct FloatingParticlesView: View {
    let particleCount = 20
    @State private var offsets: [CGSize] = Array(repeating: .zero, count: 20)
    @State private var opacities: [Double] = Array(repeating: 0.3, count: 20)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: CGFloat.random(in: 20...60), height: CGFloat.random(in: 20...60))
                        .offset(offsets[index])
                        .opacity(opacities[index])
                        .blur(radius: 8)
                }
            }
            .onAppear {
                // 初始化隨機位置
                for i in 0..<particleCount {
                    offsets[i] = CGSize(
                        width: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                        height: CGFloat.random(in: -geometry.size.height/2...geometry.size.height/2)
                    )
                }
                
                // 開始浮動動畫
                animateParticles(geometry: geometry)
            }
        }
    }
    
    private func animateParticles(geometry: GeometryProxy) {
        for i in 0..<particleCount {
            let duration = Double.random(in: 8...15)
            let delay = Double.random(in: 0...3)
            
            withAnimation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
            ) {
                offsets[i] = CGSize(
                    width: CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2),
                    height: CGFloat.random(in: -geometry.size.height/2...geometry.size.height/2)
                )
                opacities[i] = Double.random(in: 0.1...0.4)
            }
        }
    }
}

/// 漸層網格背景（Gradient Mesh）
struct GradientMeshBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 第一層漸層
                LinearGradient(
                    colors: [
                        Color.tint.opacity(0.3),
                        Color.creative.opacity(0.2),
                        Color.mint.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 第二層漸層（動態）
                LinearGradient(
                    colors: [
                        Color.creative.opacity(0.2),
                        Color.coral.opacity(0.3),
                        Color.tint.opacity(0.2)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .offset(x: sin(phase) * 50, y: cos(phase) * 50)
                .blur(radius: 80)
            }
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
    }
}

