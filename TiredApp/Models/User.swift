import Foundation
import FirebaseFirestore

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var avatarUrl: String?

    // Settings
    var timezone: String?
    var weeklyCapacityMinutes: Int?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case avatarUrl
        case timezone
        case weeklyCapacityMinutes
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        name: String,
        email: String,
        avatarUrl: String? = nil,
        timezone: String? = nil,
        weeklyCapacityMinutes: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.timezone = timezone
        self.weeklyCapacityMinutes = weeklyCapacityMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
