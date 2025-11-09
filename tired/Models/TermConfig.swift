import Foundation
import FirebaseFirestore

struct TermConfig: Codable, Identifiable {
    var id: String { termId }
    var userId: String
    var termId: String  // e.g., "113-1", "113-2", "personal-default"
    var startDate: Date?
    var endDate: Date?
    var isHolidayPeriod: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case termId = "term_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case isHolidayPeriod = "is_holiday_period"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: String, termId: String, startDate: Date?, endDate: Date?, isHolidayPeriod: Bool = false) {
        self.userId = userId
        self.termId = termId
        self.startDate = startDate
        self.endDate = endDate
        self.isHolidayPeriod = isHolidayPeriod
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
