
import SwiftUI

// MARK: - 設計系統 Token (升級版 - 心理學設計原則)

enum TTokens {
    // MARK: - 空間系統 (基於 8px 網格系統，符合人類視覺認知)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32
    static let spacingXXXL: CGFloat = 48
    
    // MARK: - 圓角半徑 (柔和的曲線帶來親和感)
    static let radiusXS: CGFloat = 6
    static let radiusSM: CGFloat = 10
    static let radiusMD: CGFloat = 14
    static let radiusLG: CGFloat = 20
    static let radiusXL: CGFloat = 28
    static let radiusCircle: CGFloat = .infinity
    
    // MARK: - 陰影系統 (深度和層次感)
    static let shadowLevel1: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
        (.black.opacity(0.04), 4, 0, 1)
    static let shadowLevel2: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
        (.black.opacity(0.08), 12, 0, 4)
    static let shadowLevel3: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
        (.black.opacity(0.12), 20, 0, 8)
    static let shadowElevated: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
        (.black.opacity(0.16), 32, 0, 12)
    
    // MARK: - 漸層系統 (溫暖的漸層帶來舒適感)
    static let gradientPrimary = LinearGradient(
        colors: [
            Color(red: 0.235, green: 0.949, blue: 0.784), // 清新的薄荷綠
            Color(red: 0.0, green: 0.682, blue: 0.937)    // 專業的藍色
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientWarm = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.596, blue: 0.353),    // 溫暖的橙黃
            Color(red: 0.964, green: 0.325, blue: 0.486) // 柔和的粉紅
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientSuccess = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.85, blue: 0.5),      // 充滿活力的綠色
            Color(red: 0.1, green: 0.75, blue: 0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientSubtle = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - 動畫時序 (符合人體工學的反應時間)
    static let animationQuick: Animation = .easeInOut(duration: 0.15)
    static let animationStandard: Animation = .spring(response: 0.3, dampingFraction: 0.8)
    static let animationSmooth: Animation = .spring(response: 0.4, dampingFraction: 0.85)
    static let animationGentle: Animation = .spring(response: 0.5, dampingFraction: 0.9)
    static let animationBouncy: Animation = .spring(response: 0.35, dampingFraction: 0.6)
    
    // MARK: - 文字大小階層 (清晰的信息架構)
    static let fontSizeXS: CGFloat = 11
    static let fontSizeSM: CGFloat = 13
    static let fontSizeMD: CGFloat = 15
    static let fontSizeLG: CGFloat = 17
    static let fontSizeXL: CGFloat = 20
    static let fontSizeXXL: CGFloat = 24
    static let fontSizeXXXL: CGFloat = 32
    
    // MARK: - 不透明度 (層次感和重點突出)
    static let opacityDisabled: Double = 0.4
    static let opacitySecondary: Double = 0.6
    static let opacityTertiary: Double = 0.8
    static let opacityFull: Double = 1.0
}

// MARK: - 顏色系統 (心理學驅動的顏色選擇)

extension Color {
    // MARK: - 基礎色彩
    static let bg = Color(uiColor: .systemBackground)
    static let bg2 = Color(uiColor: .secondarySystemBackground)
    static let bg3 = Color(uiColor: .tertiarySystemBackground)
    static let card = Color(uiColor: .systemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    
    // MARK: - 文字顏色 (確保可讀性)
    static let labelPrimary = Color(uiColor: .label)
    static let labelSecondary = Color(uiColor: .secondaryLabel)
    static let labelTertiary = Color(uiColor: .tertiaryLabel)
    
    // MARK: - 語意化顏色 (心理學優化)
    // 藍色：信任、專業、穩定
    static let tint = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let tintLight = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let tintDark = Color(red: 0.0, green: 0.3, blue: 0.8)
    
    // 綠色：成功、成長、積極
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let successLight = Color(red: 0.4, green: 0.88, blue: 0.55)
    static let successDark = Color(red: 0.1, green: 0.65, blue: 0.25)
    
    // 橙色：警告、注意、溫暖
    static let warn = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let warnLight = Color(red: 1.0, green: 0.75, blue: 0.4)
    static let warnDark = Color(red: 0.8, green: 0.45, blue: 0.0)
    
    // 紅色：錯誤、緊急、停止
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let dangerLight = Color(red: 1.0, green: 0.5, blue: 0.5)
    static let dangerDark = Color(red: 0.8, green: 0.15, blue: 0.15)
    
    // 紫色：創意、高級、神秘
    static let creative = Color(red: 0.686, green: 0.322, blue: 0.871)
    static let creativeLight = Color(red: 0.8, green: 0.5, blue: 0.9)
    
    // 中性色調（減少視覺疲勞）
    static let neutral = Color(uiColor: .systemGray)
    static let neutralLight = Color(uiColor: .systemGray5)
    static let neutralDark = Color(uiColor: .systemGray2)
}

// MARK: - View 擴充 (愉悅的互動體驗)

extension View {
    // MARK: - 卡片樣式 (帶有微妙的深度感)
    func cardStyle(
        padding: CGFloat = TTokens.spacingLG,
        radius: CGFloat = TTokens.radiusLG,
        shadowLevel: Int = 1
    ) -> some View {
        self
            .padding(padding)
            .background(Color.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.separator.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(
                color: shadowLevel == 2 ? TTokens.shadowLevel2.color : 
                       shadowLevel == 3 ? TTokens.shadowLevel3.color : TTokens.shadowLevel1.color,
                radius: shadowLevel == 2 ? TTokens.shadowLevel2.radius : 
                        shadowLevel == 3 ? TTokens.shadowLevel3.radius : TTokens.shadowLevel1.radius,
                x: shadowLevel == 2 ? TTokens.shadowLevel2.x : 
                   shadowLevel == 3 ? TTokens.shadowLevel3.x : TTokens.shadowLevel1.x,
                y: shadowLevel == 2 ? TTokens.shadowLevel2.y : 
                   shadowLevel == 3 ? TTokens.shadowLevel3.y : TTokens.shadowLevel1.y
            )
    }
    
    // MARK: - 玻璃態效果 (現代感的模糊背景)
    func glassEffect(intensity: CGFloat = 0.7) -> some View {
        self
            .background(.ultraThinMaterial.opacity(intensity), in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
    }
    
    // MARK: - 標準間距
    func standardPadding() -> some View {
        self.padding(TTokens.spacingLG)
    }
    
    // MARK: - 增加觸覺反饋的按鈕樣式
    func interactiveButtonStyle() -> some View {
        self
            .scaleEffect(1.0)
            .animation(TTokens.animationQuick, value: false)
    }
    
    // MARK: - 微動畫的出現效果
    func fadeInScale(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .scaleEffect(0.95)
            .onAppear {
                withAnimation(TTokens.animationStandard.delay(delay)) {
                    // SwiftUI 會自動處理，這裡只是標記
                }
            }
    }
    
    // MARK: - 脈衝效果（用於吸引注意力）
    func pulseEffect(isActive: Bool = true) -> some View {
        self
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(
                isActive ? 
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    .easeInOut(duration: 0.3),
                value: isActive
            )
    }
    
    // MARK: - 懸浮效果（提升互動感）
    func hoverEffect() -> some View {
        self
            .shadow(color: TTokens.shadowLevel2.color, radius: TTokens.shadowLevel2.radius, y: TTokens.shadowLevel2.y)
    }
}

// MARK: - Material 擴充

extension Material {
    static let navBarMaterial = Material.ultraThinMaterial
    static let sheetMaterial = Material.regularMaterial
    static let cardMaterial = Material.thinMaterial
}

// MARK: - 心理學設計組件

struct DelightfulButton: ViewModifier {
    let style: ButtonStyle
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary   // 主要操作
        case secondary // 次要操作
        case danger    // 危險操作
        case success   // 成功操作
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(TTokens.animationQuick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct BreathingCard: ViewModifier {
    @State private var breathing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(breathing ? 0.998 : 1.0)
            .opacity(breathing ? 0.98 : 1.0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true)
                ) {
                    breathing = true
                }
            }
    }
}

// MARK: - 動畫工具

struct AnimationHelper {
    static func staggerDelay(index: Int, baseDelay: Double = 0.05) -> Double {
        return Double(index) * baseDelay
    }
    
    static func springAnimation(response: Double = 0.3, damping: Double = 0.8) -> Animation {
        .spring(response: response, dampingFraction: damping)
    }
}
