import Foundation

enum AppConfig {
    private static let defaults = UserDefaults.standard

    // Key: CHAT_UNREAD_SAMPLE_LIMIT
    static var chatUnreadSampleLimit: Int {
        // Runtime override via UserDefaults
        if let saved = defaults.object(forKey: "CHAT_UNREAD_SAMPLE_LIMIT") as? Int { return saved }
        // Fallback to Info.plist numeric value if available
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CHAT_UNREAD_SAMPLE_LIMIT") as? Int { return plistValue }
        return 50
    }

    static func setChatUnreadSampleLimit(_ value: Int) {
        defaults.set(value, forKey: "CHAT_UNREAD_SAMPLE_LIMIT")
    }

    // Max upload sizes (bytes)
    static var maxUploadImageBytes: Int {
        if let saved = defaults.object(forKey: "MAX_UPLOAD_IMAGE_BYTES") as? Int { return saved }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "MAX_UPLOAD_IMAGE_BYTES") as? Int { return plistValue }
        return 2_000_000 // 2 MB
    }

    static var maxUploadVideoBytes: Int {
        if let saved = defaults.object(forKey: "MAX_UPLOAD_VIDEO_BYTES") as? Int { return saved }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "MAX_UPLOAD_VIDEO_BYTES") as? Int { return plistValue }
        return 20_000_000 // 20 MB
    }

    // Max image pixel dimension (longest side)
    static var maxImageMaxDimension: Int {
        if let saved = defaults.object(forKey: "MAX_IMAGE_MAX_DIMENSION") as? Int { return saved }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "MAX_IMAGE_MAX_DIMENSION") as? Int { return plistValue }
        return 1600
    }

    static var videoThumbMaxItems: Int {
        if let saved = defaults.object(forKey: "VIDEO_THUMB_MAX_ITEMS") as? Int { return saved }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "VIDEO_THUMB_MAX_ITEMS") as? Int { return plistValue }
        return 200
    }

    static var videoThumbTtlDays: Int {
        if let saved = defaults.object(forKey: "VIDEO_THUMB_TTL_DAYS") as? Int { return saved }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "VIDEO_THUMB_TTL_DAYS") as? Int { return plistValue }
        return 14
    }
}
