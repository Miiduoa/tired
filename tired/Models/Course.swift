import Foundation
import SwiftUI

// MARK: - Course Model
struct Course: Codable, Identifiable {
    var id: String
    var userId: String
    var termId: String

    // Basic Info
    var name: String
    var courseCode: String?
    var instructor: String?
    var credits: Int?
    var color: String // Hex color code

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        termId: String,
        name: String,
        courseCode: String? = nil,
        instructor: String? = nil,
        credits: Int? = nil,
        color: String = "#3B82F6", // Default blue
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.termId = termId
        self.name = name
        self.courseCode = courseCode
        self.instructor = instructor
        self.credits = credits
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Course Helpers
extension Course {
    // Get SwiftUI Color from hex string
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }

    // Display name with code
    var displayName: String {
        if let code = courseCode, !code.isEmpty {
            return "\(code) - \(name)"
        }
        return name
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
