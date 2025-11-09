import Foundation
import FirebaseFirestore

struct Course: Codable, Identifiable {
    var id: String = UUID().uuidString
    var userId: String
    var termId: String

    var name: String
    var courseCode: String?
    var instructor: String?
    var credits: Int?
    var color: String

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case termId = "term_id"
        case name
        case courseCode = "course_code"
        case instructor
        case credits
        case color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, userId: String, termId: String, name: String, color: String = "#007AFF") {
        self.id = id
        self.userId = userId
        self.termId = termId
        self.name = name
        self.color = color
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
