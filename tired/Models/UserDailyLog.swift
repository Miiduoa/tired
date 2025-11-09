import Foundation

// MARK: - User Daily Log Model
struct UserDailyLog: Codable, Identifiable {
    var id: String
    var userId: String
    var date: Date // Store as Date, will be indexed in Firestore

    // Reflection
    var highlight: String?
    var mood: Mood?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    enum Mood: String, Codable, CaseIterable {
        case good = "good"
        case ok = "ok"
        case bad = "bad"

        var emoji: String {
            switch self {
            case .good: return "😊"
            case .ok: return "😐"
            case .bad: return "😔"
            }
        }

        var displayText: String {
            switch self {
            case .good: return "很好"
            case .ok: return "還可以"
            case .bad: return "不太好"
            }
        }
    }

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        date: Date,
        highlight: String? = nil,
        mood: Mood? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.highlight = highlight
        self.mood = mood
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - User Daily Log Helpers
extension UserDailyLog {
    var hasContent: Bool {
        return highlight != nil || mood != nil
    }
}
