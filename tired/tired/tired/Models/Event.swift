import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Event

struct Event: Codable, Identifiable {
    @DocumentID var id: String?
    var orgAppInstanceId: String
    var organizationId: String

    var title: String
    var description: String?

    var startAt: Date
    var endAt: Date?

    var location: String?
    var capacity: Int?
    var isCancelled: Bool

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orgAppInstanceId
        case organizationId
        case title
        case description
        case startAt
        case endAt
        case location
        case capacity
        case isCancelled
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        orgAppInstanceId: String,
        organizationId: String,
        title: String,
        description: String? = nil,
        startAt: Date,
        endAt: Date? = nil,
        location: String? = nil,
        capacity: Int? = nil,
        isCancelled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orgAppInstanceId = orgAppInstanceId
        self.organizationId = organizationId
        self.title = title
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.location = location
        self.capacity = capacity
        self.isCancelled = isCancelled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - EventRegistration

struct EventRegistration: Codable, Identifiable {
    @DocumentID var id: String?
    var eventId: String
    var userId: String

    var status: EventRegistrationStatus
    var registeredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case userId
        case status
        case registeredAt
    }

    init(
        id: String? = nil,
        eventId: String,
        userId: String,
        status: EventRegistrationStatus = .registered,
        registeredAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.status = status
        self.registeredAt = registeredAt
    }
}

// MARK: - Event with Registration (for UI)

struct EventWithRegistration: Identifiable {
    let event: Event
    let registration: EventRegistration?
    let organization: Organization?

    var id: String? { event.id }

    var isRegistered: Bool {
        registration?.status == .registered
    }
}
