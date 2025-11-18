import Foundation
import FirebaseFirestore
import Combine

/// 活動服務
class EventService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Fetch Events

    /// 獲取組織的活動
    func fetchOrganizationEvents(organizationId: String) -> AnyPublisher<[Event], Error> {
        let subject = PassthroughSubject<[Event], Error>()

        db.collection("events")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("isCancelled", isEqualTo: false)
            .order(by: "startAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let events = documents.compactMap { doc -> Event? in
                    try? doc.data(as: Event.self)
                }

                subject.send(events)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 獲取用戶報名的活動
    func fetchUserRegisteredEvents(userId: String) async throws -> [EventWithRegistration] {
        // 獲取用戶的報名記錄
        let registrations = try await db.collection("eventRegistrations")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: EventRegistrationStatus.registered.rawValue)
            .getDocuments()

        var results: [EventWithRegistration] = []

        for regDoc in registrations.documents {
            guard let registration = try? regDoc.data(as: EventRegistration.self),
                  let eventId = registration.eventId as String? else { continue }

            // 獲取對應的活動
            let eventDoc = try? await db.collection("events").document(eventId).getDocument()
            guard let event = try? eventDoc?.data(as: Event.self) else { continue }

            // 獲取組織信息
            let orgDoc = try? await db.collection("organizations").document(event.organizationId).getDocument()
            let organization = try? orgDoc?.data(as: Organization.self)

            results.append(EventWithRegistration(
                event: event,
                registration: registration,
                organization: organization
            ))
        }

        return results
    }

    // MARK: - CRUD Operations

    /// 創建活動
    func createEvent(_ event: Event) async throws -> String {
        var newEvent = event
        newEvent.createdAt = Date()
        newEvent.updatedAt = Date()

        let ref = try db.collection("events").addDocument(from: newEvent)
        return ref.documentID
    }

    /// 更新活動
    func updateEvent(_ event: Event) async throws {
        guard let id = event.id else {
            throw NSError(domain: "EventService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event ID is missing"])
        }

        var updatedEvent = event
        updatedEvent.updatedAt = Date()

        try db.collection("events").document(id).setData(from: updatedEvent)
    }

    /// 取消活動
    func cancelEvent(id: String) async throws {
        try await db.collection("events").document(id).updateData([
            "isCancelled": true,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Registration

    /// 報名活動
    func registerForEvent(eventId: String, userId: String) async throws {
        // 檢查是否已報名
        let existing = try await db.collection("eventRegistrations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        if !existing.documents.isEmpty {
            throw NSError(domain: "EventService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already registered"])
        }

        let registration = EventRegistration(
            eventId: eventId,
            userId: userId,
            status: .registered,
            registeredAt: Date()
        )

        _ = try db.collection("eventRegistrations").addDocument(from: registration)
    }

    /// 取消報名
    func cancelRegistration(eventId: String, userId: String) async throws {
        let snapshot = try await db.collection("eventRegistrations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in snapshot.documents {
            try await db.collection("eventRegistrations").document(doc.documentID).updateData([
                "status": EventRegistrationStatus.cancelled.rawValue
            ])
        }
    }

    /// 獲取活動報名人數
    func getRegistrationCount(eventId: String) async throws -> Int {
        let snapshot = try await db.collection("eventRegistrations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("status", isEqualTo: EventRegistrationStatus.registered.rawValue)
            .getDocuments()

        return snapshot.documents.count
    }

    /// 檢查用戶是否已報名
    func isUserRegistered(eventId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("eventRegistrations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: EventRegistrationStatus.registered.rawValue)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }
}
