import Foundation
import FirebaseFirestore

struct Event: Codable, Identifiable {
    var id: String = UUID().uuidString
    var userId: String

    var title: String
    var startAt: Date
    var endAt: Date
    var startDate: String  // YYYY-MM-DD
    var endDate: String    // YYYY-MM-DD

    var location: String
    var type: EventType
    var blocksStudyTime: Bool
    var isAllDay: Bool

    var createdAt: Date
    var updatedAt: Date

    enum EventType: String, Codable {
        case `class`
        case work
        case exam
        case meeting
        case other
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case startAt = "start_at"
        case endAt = "end_at"
        case startDate = "start_date"
        case endDate = "end_date"
        case location
        case type
        case blocksStudyTime = "blocks_study_time"
        case isAllDay = "is_all_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, userId: String, title: String, startAt: Date, endAt: Date, type: EventType) {
        self.id = id
        self.userId = userId
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.startDate = ""  // Will be set by helper
        self.endDate = ""
        self.location = ""
        self.type = type

        // Default blocksStudyTime based on type
        switch type {
        case .class, .work, .exam, .meeting:
            self.blocksStudyTime = true
        case .other:
            self.blocksStudyTime = false
        }

        self.isAllDay = false
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
