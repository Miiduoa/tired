import Foundation
import SwiftUI

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: String?
    let provider: String
    let phoneNumber: String?
    let isEmailVerified: Bool
    let isPhoneVerified: Bool
    let createdAt: Date
    let lastLoginAt: Date
    let preferences: UserPreferences
    
    init(
        id: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        provider: String,
        phoneNumber: String? = nil,
        isEmailVerified: Bool = false,
        isPhoneVerified: Bool = false,
        createdAt: Date = Date(),
        lastLoginAt: Date = Date(),
        preferences: UserPreferences = UserPreferences()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.phoneNumber = phoneNumber
        self.isEmailVerified = isEmailVerified
        self.isPhoneVerified = isPhoneVerified
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.preferences = preferences
    }
    
    var initials: String {
        let components = displayName.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if !displayName.isEmpty {
            return String(displayName.prefix(2))
        } else if !email.isEmpty {
            return String(email.prefix(2))
        }
        return "U"
    }
    
    var avatarURL: URL? {
        guard let photoURL = photoURL else { return nil }
        return URL(string: photoURL)
    }
    
    var isFullyVerified: Bool {
        isEmailVerified && (phoneNumber == nil || isPhoneVerified)
    }
    
    var verificationStatus: UserVerificationStatus {
        if isFullyVerified { return .verified }
        if isEmailVerified { return .emailVerified }
        return .unverified
    }
}

struct UserPreferences: Codable {
    var showSocialFeed: Bool
    var enableNotifications: Bool
    var preferredLanguage: String
    var themePreference: ThemePreference
    
    init(
        showSocialFeed: Bool = true,
        enableNotifications: Bool = true,
        preferredLanguage: String = "zh-TW",
        themePreference: ThemePreference = .system
    ) {
        self.showSocialFeed = showSocialFeed
        self.enableNotifications = enableNotifications
        self.preferredLanguage = preferredLanguage
        self.themePreference = themePreference
    }
}

enum ThemePreference: String, CaseIterable, Codable {
    case system = "跟隨系統"
    case light = "淺色"
    case dark = "深色"
    case psychology = "心理學模式"
}

enum UserVerificationStatus: String, CaseIterable, Codable {
    case unverified = "未驗證"
    case emailVerified = "郵箱已驗證"
    case verified = "完全驗證"
    
    var title: String { rawValue }
    
    var color: Color {
        switch self {
        case .unverified: return .red
        case .emailVerified: return .orange
        case .verified: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .unverified: return "xmark.circle.fill"
        case .emailVerified: return "envelope.circle.fill"
        case .verified: return "checkmark.circle.fill"
        }
    }
}
