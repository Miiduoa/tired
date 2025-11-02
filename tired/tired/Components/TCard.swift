import SwiftUI
import Combine

// MARK: - 現代化卡片組件（心理學優化）

struct TCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailingSystemImage: String?
    let style: CardStyle
    let accentColor: Color
    @ViewBuilder var content: Content
    @State private var isPressed = false
    
    enum CardStyle {
        case standard        // 標準卡片
        case elevated       // 提升卡片（更多陰影）
        case glass          // 玻璃態
        case gradient       // 漸層背景
        case outlined       // 外框樣式
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        trailingSystemImage: String? = nil,
        style: CardStyle = .standard,
        accentColor: Color = .tint,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingSystemImage = trailingSystemImage
        self.style = style
        self.accentColor = accentColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            // 標題區塊
            HStack(spacing: TTokens.spacingMD) {
                VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.labelPrimary)
                    if let s = subtitle {
                        Text(s)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let icon = trailingSystemImage {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(accentColor.gradient)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            
            // 內容區塊
            content
        }
        .padding(TTokens.spacingLG)
        .background {
            cardBackground
        }
        .overlay {
            cardOverlay
        }
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            y: shadowY
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(TTokens.animationQuick, value: isPressed)
    }
    
    // MARK: - 背景樣式
    
    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
        
        switch style {
        case .standard:
            shape.fill(Color.card)
        case .elevated:
            shape.fill(Color.card)
        case .glass:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(accentColor.opacity(0.05))
            }
        case .gradient:
            shape.fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .outlined:
            shape.fill(Color.bg)
        }
    }
    
    // MARK: - 邊框樣式
    
    @ViewBuilder
    private var cardOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
        
        switch style {
        case .standard, .elevated:
            shape.strokeBorder(Color.separator.opacity(0.5), lineWidth: 0.5)
        case .glass:
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
        case .gradient:
            shape.strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        case .outlined:
            shape.strokeBorder(accentColor.opacity(0.5), lineWidth: 1.5)
        }
    }
    
    // MARK: - 陰影配置
    
    private var shadowColor: Color {
        switch style {
        case .elevated:
            return .black.opacity(0.12)
        case .glass:
            return .black.opacity(0.08)
        default:
            return .black.opacity(0.06)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated:
            return 16
        case .glass:
            return 12
        default:
            return 8
        }
    }
    
    private var shadowY: CGFloat {
        switch style {
        case .elevated:
            return 10
        case .glass:
            return 6
        default:
            return 4
        }
    }
}
