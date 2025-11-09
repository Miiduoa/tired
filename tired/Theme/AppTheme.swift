import SwiftUI

/// 應用主題系統 - iOS 現代化玻璃效果
struct AppTheme {

    // MARK: - Colors

    static let primaryColor = Color("Primary", bundle: nil) ?? Color.blue
    static let secondaryColor = Color("Secondary", bundle: nil) ?? Color.purple
    static let accentColor = Color("Accent", bundle: nil) ?? Color.pink

    static let backgroundPrimary = Color("BackgroundPrimary", bundle: nil) ?? Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color("BackgroundSecondary", bundle: nil) ?? Color(uiColor: .secondarySystemBackground)

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // Priority Colors
    static let priorityP0 = Color.red
    static let priorityP1 = Color.orange
    static let priorityP2 = Color.blue
    static let priorityP3 = Color.gray

    // Category Colors
    static let categorySchool = Color.blue
    static let categoryWork = Color.orange
    static let categoryPersonal = Color.purple
    static let categoryOther = Color.gray

    // Status Colors
    static let successColor = Color.green
    static let warningColor = Color.orange
    static let errorColor = Color.red

    // MARK: - Spacing

    static let spacing: CGFloat = 8
    static let spacing2: CGFloat = 16
    static let spacing3: CGFloat = 24
    static let spacing4: CGFloat = 32
    static let spacing5: CGFloat = 40

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24

    // MARK: - Typography

    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let subheadline = Font.system(size: 17, weight: .medium, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 14, weight: .regular, design: .default)
    static let footnote = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: - Glass Effects (iOS 15+)

    /// 超薄材質 - 用於浮動元素、卡片
    static let ultraThinMaterial = Material.ultraThinMaterial

    /// 薄材質 - 用於工具欄、選單
    static let thinMaterial = Material.thinMaterial

    /// 標準材質 - 用於主要背景
    static let regularMaterial = Material.regularMaterial

    /// 厚材質 - 用於模態視圖
    static let thickMaterial = Material.thickMaterial

    /// 粗材質 - 用於強調區域
    static let ultraThickMaterial = Material.ultraThickMaterial

    // MARK: - Shadows

    static let shadowColor = Color.black.opacity(0.1)
    static let shadowRadius: CGFloat = 10
    static let shadowOffset = CGSize(width: 0, height: 4)

    // MARK: - Animations

    static let quickAnimation = Animation.easeOut(duration: 0.2)
    static let normalAnimation = Animation.easeInOut(duration: 0.3)
    static let slowAnimation = Animation.easeInOut(duration: 0.5)
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.75)
}

// MARK: - View Extensions for Glass Effect

extension View {

    /// 應用玻璃卡片樣式
    func glassCard(padding: CGFloat = AppTheme.spacing2) -> some View {
        self
            .padding(padding)
            .background(AppTheme.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: 4)
    }

    /// 應用玻璃背景
    func glassBackground() -> some View {
        self
            .background(AppTheme.thinMaterial)
    }

    /// 應用主要卡片樣式
    func mainCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 2)
    }

    /// 應用模態視圖樣式
    func modalStyle() -> some View {
        self
            .background(AppTheme.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    /// 應用次要按鈕樣式（玻璃效果）
    func glassButton() -> some View {
        self
            .padding(.horizontal, AppTheme.spacing2)
            .padding(.vertical, AppTheme.spacing)
            .background(AppTheme.thinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    /// 應用主要按鈕樣式
    func primaryButton() -> some View {
        self
            .padding(.horizontal, AppTheme.spacing3)
            .padding(.vertical, AppTheme.spacing2)
            .background(
                LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: AppTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    /// 應用次要按鈕樣式
    func secondaryButton() -> some View {
        self
            .padding(.horizontal, AppTheme.spacing2)
            .padding(.vertical, AppTheme.spacing)
            .background(AppTheme.backgroundSecondary)
            .foregroundColor(AppTheme.textPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - Priority Extensions

extension Task.Priority {
    var color: Color {
        switch self {
        case .P0: return AppTheme.priorityP0
        case .P1: return AppTheme.priorityP1
        case .P2: return AppTheme.priorityP2
        case .P3: return AppTheme.priorityP3
        }
    }

    var label: String {
        switch self {
        case .P0: return "緊急"
        case .P1: return "重要"
        case .P2: return "一般"
        case .P3: return "低優先"
        }
    }
}

// MARK: - Category Extensions

extension Task.TaskCategory {
    var color: Color {
        switch self {
        case .school: return AppTheme.categorySchool
        case .work: return AppTheme.categoryWork
        case .personal: return AppTheme.categoryPersonal
        case .other: return AppTheme.categoryOther
        }
    }

    var icon: String {
        switch self {
        case .school: return "book.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .other: return "folder.fill"
        }
    }

    var label: String {
        switch self {
        case .school: return "學校"
        case .work: return "工作"
        case .personal: return "個人"
        case .other: return "其他"
        }
    }
}
