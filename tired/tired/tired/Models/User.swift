import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var avatarUrl: String?
    var fcmToken: String? // For push notifications

    // Time Management Settings
    var timezone: String?
    var weeklyCapacityMinutes: Int?
    var dailyCapacityMinutes: Int?

    // Notification Settings
    var notificationsEnabled: Bool?
    var taskReminders: Bool?
    var eventReminders: Bool?
    var organizationUpdates: Bool?

    // Appearance Settings
    var theme: String?  // "auto", "light", "dark"

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case avatarUrl
        case fcmToken
        case timezone
        case weeklyCapacityMinutes
        case dailyCapacityMinutes
        case notificationsEnabled
        case taskReminders
        case eventReminders
        case organizationUpdates
        case theme
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        name: String,
        email: String,
        avatarUrl: String? = nil,
        fcmToken: String? = nil,
        timezone: String? = nil,
        weeklyCapacityMinutes: Int? = nil,
        dailyCapacityMinutes: Int? = nil,
        notificationsEnabled: Bool? = true,
        taskReminders: Bool? = true,
        eventReminders: Bool? = true,
        organizationUpdates: Bool? = true,
        theme: String? = "auto",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.fcmToken = fcmToken
        self.timezone = timezone
        self.weeklyCapacityMinutes = weeklyCapacityMinutes
        self.dailyCapacityMinutes = dailyCapacityMinutes
        self.notificationsEnabled = notificationsEnabled
        self.taskReminders = taskReminders
        self.eventReminders = eventReminders
        self.organizationUpdates = organizationUpdates
        self.theme = theme
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
