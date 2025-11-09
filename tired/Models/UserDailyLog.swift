import Foundation
import FirebaseFirestore

struct UserDailyLog: Codable, Identifiable {
    var id: String { "\(userId)_\(dateString)" }
    var userId: String
    var date: Date
    var dateString: String  // YYYY-MM-DD for querying
    var highlight: String?
    var mood: Mood?
    var createdAt: Date
    var updatedAt: Date

    enum Mood: String, Codable {
        case good
        case ok
        case bad
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case dateString = "date_string"
        case highlight
        case mood
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: String, date: Date, highlight: String? = nil, mood: Mood? = nil) {
        self.userId = userId
        self.date = date
        self.dateString = DateUtils.formatDateKey(date)
        self.highlight = highlight
        self.mood = mood
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
