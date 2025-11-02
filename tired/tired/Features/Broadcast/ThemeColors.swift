// ThemeColors.swift
import SwiftUI

// Expose semantic colors as ShapeStyle members so you can write `.foregroundStyle(.success)`,
// and also use them as `Color.success`.
public extension ShapeStyle where Self == Color {
    static var success: Color { .green }
    static var danger: Color { .red }
    static var warn: Color { .orange }
    static var creative: Color { .purple }
    static var tint: Color { .accentColor }

    // Surfaces and separators
    static var bg: Color { Color(uiColor: .systemBackground) }
    static var bg2: Color { Color(uiColor: .secondarySystemBackground) }
    static var card: Color { Color(uiColor: .secondarySystemBackground) }
    static var separator: Color { Color.black.opacity(0.12) }

    // Text convenience
    static var labelPrimary: Color { .primary }
    static var labelSecondary: Color { .secondary }
    static var labelTertiary: Color { .tertiary }
}
