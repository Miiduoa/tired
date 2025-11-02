import SwiftUI

/// 深色模式顏色擴展
extension Color {
    // MARK: - 語意化顏色（支援深色模式）
    
    static let bg = Color("Background", bundle: nil)
    static let bg2 = Color("SecondaryBackground", bundle: nil)
    static let cardBg = Color("CardBackground", bundle: nil)
    
    static let label = Color("Label", bundle: nil)
    static let secLabel = Color("SecondaryLabel", bundle: nil)
    static let terLabel = Color("TertiaryLabel", bundle: nil)
    
    static let accent = Color("AccentColor", bundle: nil)
    static let success = Color("Success", bundle: nil)
    static let warning = Color("Warning", bundle: nil)
    static let danger = Color("Danger", bundle: nil)
    
    static let separator = Color("Separator", bundle: nil)
    
    // MARK: - Fallback 系統顏色
    
    static var adaptiveBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    static var adaptiveSecondaryBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    static var adaptiveTertiaryBackground: Color {
        Color(UIColor.tertiarySystemBackground)
    }
    
    static var adaptiveGroupedBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }
    
    static var adaptiveLabel: Color {
        Color(UIColor.label)
    }
    
    static var adaptiveSecondaryLabel: Color {
        Color(UIColor.secondaryLabel)
    }
    
    static var adaptiveTertiaryLabel: Color {
        Color(UIColor.tertiaryLabel)
    }
    
    static var adaptiveSeparator: Color {
        Color(UIColor.separator)
    }
    
    // MARK: - 漸層色
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "3CF2C8"), Color(hex: "00AEEF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var darkGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "0B1B2B"), Color(hex: "1a2332")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Hex 初始化
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor 擴展

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

