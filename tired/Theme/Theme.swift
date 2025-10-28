
import SwiftUI

// 現代化 Token（簡化版）
enum TTokens {
    static let radiusXS: CGFloat = 8
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 24
    
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    
    static let gradient = LinearGradient(
        colors: [Color(red: 0.235, green: 0.949, blue: 0.784), Color(red: 0.0, green: 0.682, blue: 0.937)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// iOS Semantic Colors：使用系統自動深/淺色
extension Color {
    static let bg = Color(uiColor: .systemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let labelPrimary = Color(uiColor: .label)
    static let labelSecondary = Color(uiColor: .secondaryLabel)
}
