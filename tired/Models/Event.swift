import Foundation
import FirebaseFirestore

// MARK: - Event Type
enum EventType: String, Codable, CaseIterable {
    case `class` = "class"
    case work = "work"
    case exam = "exam"
    case meeting = "meeting"
    case other = "other"

    var blocksStudyTimeByDefault: Bool {
        switch self {
        case .class, .work, .exam, .meeting:
            return true
        case .other:
            return false
        }
    }
}

// MARK: - Event Model
struct Event: Codable, Identifiable {
    var id: String
    var userId: String

    // Basic Info
    var title: String
    var startAt: Date
    var endAt: Date
    var startDate: String // 'YYYY-MM-DD' denormalized
    var endDate: String   // 'YYYY-MM-DD' denormalized

    // Details
    var location: String
    var type: EventType
    var blocksStudyTime: Bool
    var isAllDay: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        startAt: Date,
        endAt: Date,
        startDate: String,
        endDate: String,
        location: String = "",
        type: EventType = .other,
        blocksStudyTime: Bool? = nil,
        isAllDay: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.type = type
        self.blocksStudyTime = blocksStudyTime ?? type.blocksStudyTimeByDefault
        self.isAllDay = isAllDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Event Task Link
struct EventTaskLink: Codable, Identifiable {
    var id: String
    var eventId: String
    var taskId: String
    var autoSyncDeadline: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String,
        taskId: String,
        autoSyncDeadline: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.taskId = taskId
        self.autoSyncDeadline = autoSyncDeadline
        self.createdAt = createdAt
    }
}

// MARK: - Event Helpers
extension Event {
    // Calculate duration in minutes
    var durationMinutes: Int {
        let duration = endAt.timeIntervalSince(startAt)
        return max(Int(duration / 60), 0)
    }

    // Get effective start/end for all-day events
    func effectiveStartTime(timeZone: TimeZone = .current) -> Date {
        if isAllDay {
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            var components = calendar.dateComponents([.year, .month, .day], from: startAt)
            components.hour = 8
            components.minute = 0
            return calendar.date(from: components) ?? startAt
        }
        return startAt
    }

    func effectiveEndTime(timeZone: TimeZone = .current) -> Date {
        if isAllDay {
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            var components = calendar.dateComponents([.year, .month, .day], from: endAt)
            components.hour = 16
            components.minute = 0
            return calendar.date(from: components) ?? endAt
        }
        return endAt
    }
}
