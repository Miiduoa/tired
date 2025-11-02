
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
    
    // MARK: - 漸層系統 (情感化色彩流動 - 心理學驅動)
    
    // 主品牌漸層：信任 + 專業 + 未來感
    static let gradientPrimary = LinearGradient(
        colors: [
            Color(red: 0.32, green: 0.68, blue: 1.0),     // 天空藍
            Color(red: 0.18, green: 0.52, blue: 0.95)     // 深海藍
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 薄荷漸層：清新 + 療癒 + 放鬆
    static let gradientMint = LinearGradient(
        colors: [
            Color(red: 0.28, green: 0.95, blue: 0.82),    // 薄荷綠
            Color(red: 0.18, green: 0.82, blue: 0.92)     // 青色
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 溫暖漸層：友好 + 活力 + 積極
    static let gradientWarm = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.68, blue: 0.42),     // 橙色
            Color(red: 1.0, green: 0.52, blue: 0.58)      // 珊瑚粉
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 成功漸層：成長 + 正向 + 成就
    static let gradientSuccess = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.9, blue: 0.6),      // 淺綠
            Color(red: 0.22, green: 0.82, blue: 0.4)      // 鮮綠
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 紫色漸層：創意 + 高級 + 神秘
    static let gradientCreative = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.58, blue: 0.95),    // 淺紫
            Color(red: 0.68, green: 0.35, blue: 0.88)     // 深紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 日落漸層：溫暖 + 浪漫 + 柔和
    static let gradientSunset = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.75, blue: 0.58),     // 橙黃
            Color(red: 0.98, green: 0.52, blue: 0.72),    // 粉橙
            Color(red: 0.88, green: 0.42, blue: 0.85)     // 紫粉
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 微妙漸層：極簡 + 高級 + 克制
    static let gradientSubtle = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // 玻璃漸層：現代 + 透明 + 層次
    static let gradientGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.4),
            Color.white.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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

// MARK: - 顏色系統 (心理學驅動的顏色選擇 - 升級版)

extension Color {
    // MARK: - 基礎色彩（動態適配）
    static let bg = Color(uiColor: .systemBackground)
    static let bg2 = Color(uiColor: .secondarySystemBackground)
    static let bg3 = Color(uiColor: .tertiarySystemBackground)
    static let card = Color(uiColor: .systemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    
    // MARK: - 文字顏色（可讀性優化）
    static let labelPrimary = Color(uiColor: .label)
    static let labelSecondary = Color(uiColor: .secondaryLabel)
    static let labelTertiary = Color(uiColor: .tertiaryLabel)
    
    // MARK: - 品牌色彩（情感化設計）
    // 藍色：信任、專業、穩定 - 升級為更柔和的色調
    static let tint = Color(red: 0.2, green: 0.58, blue: 1.0)  // 更溫暖的藍
    static let tintLight = Color(red: 0.5, green: 0.75, blue: 1.0)
    static let tintDark = Color(red: 0.0, green: 0.35, blue: 0.85)
    static let tintUltraLight = Color(red: 0.85, green: 0.92, blue: 1.0)  // 新增：極淺色用於背景
    
    // 綠色：成功、成長、積極 - 更有生命力
    static let success = Color(red: 0.22, green: 0.82, blue: 0.4)
    static let successLight = Color(red: 0.45, green: 0.9, blue: 0.6)
    static let successDark = Color(red: 0.1, green: 0.68, blue: 0.28)
    static let successBg = Color(red: 0.9, green: 0.98, blue: 0.93)  // 新增：背景色
    
    // 橙色：警告、注意、溫暖 - 更友好
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.15)
    static let warnLight = Color(red: 1.0, green: 0.78, blue: 0.45)
    static let warnDark = Color(red: 0.85, green: 0.48, blue: 0.0)
    static let warnBg = Color(red: 1.0, green: 0.96, blue: 0.88)  // 新增：背景色
    
    // 紅色：錯誤、緊急 - 更克制
    static let danger = Color(red: 1.0, green: 0.28, blue: 0.24)
    static let dangerLight = Color(red: 1.0, green: 0.55, blue: 0.52)
    static let dangerDark = Color(red: 0.85, green: 0.18, blue: 0.18)
    static let dangerBg = Color(red: 1.0, green: 0.95, blue: 0.95)  // 新增：背景色
    
    // 紫色：創意、高級、神秘 - 更優雅
    static let creative = Color(red: 0.72, green: 0.38, blue: 0.90)
    static let creativeLight = Color(red: 0.85, green: 0.58, blue: 0.95)
    static let creativeDark = Color(red: 0.58, green: 0.25, blue: 0.75)
    static let creativeBg = Color(red: 0.96, green: 0.93, blue: 0.98)  // 新增：背景色
    
    // 薄荷綠：清新、療癒、放鬆（新增）
    static let mint = Color(red: 0.28, green: 0.95, blue: 0.82)
    static let mintLight = Color(red: 0.58, green: 0.98, blue: 0.92)
    static let mintBg = Color(red: 0.92, green: 0.99, blue: 0.98)
    
    // 珊瑚色：溫暖、友好、活力（新增）
    static let coral = Color(red: 1.0, green: 0.65, blue: 0.52)
    static let coralLight = Color(red: 1.0, green: 0.82, blue: 0.75)
    static let coralBg = Color(red: 1.0, green: 0.96, blue: 0.94)
    
    // 中性色調（高級灰）
    static let neutral = Color(uiColor: .systemGray)
    static let neutralLight = Color(uiColor: .systemGray5)
    static let neutralDark = Color(uiColor: .systemGray2)
    static let neutralBg = Color(uiColor: .systemGray6)
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
    
    // MARK: - 玻璃態效果（Glassmorphism - iOS 風格）
    func glassEffect(
        intensity: CGFloat = 0.7,
        radius: CGFloat = TTokens.radiusLG,
        borderOpacity: Double = 0.3
    ) -> some View {
        self
            .background(.ultraThinMaterial.opacity(intensity), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(borderOpacity), .white.opacity(borderOpacity * 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
    
    // MARK: - 漸層玻璃卡片（現代感強烈）
    func gradientGlassCard(gradient: LinearGradient = TTokens.gradientPrimary) -> some View {
        self
            .padding(TTokens.spacingLG)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                        .fill(gradient.opacity(0.15))
                    RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: TTokens.shadowLevel2.color, radius: TTokens.shadowLevel2.radius, y: TTokens.shadowLevel2.y)
    }
    
    // MARK: - 標準間距
    func standardPadding() -> some View {
        self.padding(TTokens.spacingLG)
    }
    
    // MARK: - 💫 情感化微交互（Delightful Microinteractions）
    
    /// 彈性按壓效果 - 適用於按鈕，帶觸覺反饋
    func bouncyPress(isPressed: Bool = false) -> some View {
        self
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(TTokens.animationBouncy, value: isPressed)
    }
    
    /// 漸入放大 - 列表項目進場動畫
    func fadeInScale(delay: Double = 0, scale: CGFloat = 0.92) -> some View {
        self
            .opacity(0)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(TTokens.animationSmooth.delay(delay)) {
                    // SwiftUI 會自動處理，這裡只是標記
                }
            }
    }
    
    /// 呼吸脈衝 - 吸引注意力的柔和動畫
    func breathingPulse(isActive: Bool = true, scale: CGFloat = 1.02, duration: Double = 2.0) -> some View {
        self
            .scaleEffect(isActive ? scale : 1.0)
            .opacity(isActive ? 0.95 : 1.0)
            .animation(
                isActive ?
                    .easeInOut(duration: duration).repeatForever(autoreverses: true) :
                    .easeInOut(duration: 0.3),
                value: isActive
            )
    }
    
    /// 懸浮提升 - 卡片互動時的深度感
    func floatingLift(isLifted: Bool = false) -> some View {
        self
            .shadow(
                color: .black.opacity(isLifted ? 0.15 : 0.06),
                radius: isLifted ? 20 : 8,
                y: isLifted ? 12 : 4
            )
            .scaleEffect(isLifted ? 1.02 : 1.0)
            .animation(TTokens.animationSmooth, value: isLifted)
    }
    
    /// 漣漪擴散 - 點擊反饋動畫
    func rippleEffect(at point: CGPoint = .zero, isActive: Bool = false) -> some View {
        self
            .overlay {
                if isActive {
                    Circle()
                        .fill(Color.tint.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .position(point)
                        .scaleEffect(isActive ? 5 : 1)
                        .opacity(isActive ? 0 : 0.8)
                        .animation(.easeOut(duration: 0.5), value: isActive)
                }
            }
    }
    
    /// 彈出出現 - 驚喜元素動畫
    func popIn(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .scaleEffect(0.5)
            .onAppear {
                withAnimation(TTokens.animationBouncy.delay(delay)) {
                    // SwiftUI 會自動處理
                }
            }
    }
    
    /// 搖晃提示 - 錯誤或需要注意時
    func shakeEffect(trigger: Int = 0) -> some View {
        self
            .modifier(ShakeEffect(shakes: trigger))
    }
    
    /// 閃爍高亮 - 臨時突出顯示
    func highlightFlash(isActive: Bool = false, color: Color = .tint) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous)
                    .fill(color.opacity(isActive ? 0.2 : 0))
                    .animation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true), value: isActive)
            )
    }

    // MARK: - 統一按鈕樣式（主要/次要）
    func tPrimaryButton(fullWidth: Bool = false) -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.vertical, TTokens.spacingSM)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(TTokens.gradientPrimary, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
            .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
    }

    func tSecondaryButton(fullWidth: Bool = false) -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.tint)
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.vertical, TTokens.spacingSM)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.neutralLight, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .strokeBorder(Color.separator.opacity(0.5), lineWidth: 0.5)
            }
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

// MARK: - 搖晃效果（錯誤提示）

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 8 * sin(animatableData * 2 * .pi * 3)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
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
