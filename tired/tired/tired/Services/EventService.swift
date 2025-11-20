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

        // 獲取活動詳情
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        guard let event = try? eventDoc.data(as: Event.self) else {
            throw NSError(domain: "EventService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }

        // 創建報名記錄
        let registration = EventRegistration(
            eventId: eventId,
            userId: userId,
            status: .registered,
            registeredAt: Date()
        )

        _ = try db.collection("eventRegistrations").addDocument(from: registration)

        // 自動創建任務
        try await createTaskForEvent(event: event, userId: userId)
    }

    /// 為活動創建任務
    private func createTaskForEvent(event: Event, userId: String) async throws {
        // 創建任務，標題為活動名稱，截止日期為活動開始時間
        let task = Task(
            userId: userId,
            sourceOrgId: event.organizationId,
            sourceAppInstanceId: event.orgAppInstanceId,
            sourceType: .eventSignup,
            title: "參加活動：\(event.title)",
            description: event.description,
            category: .personal,
            priority: .high,  // 活動通常比較重要
            deadlineAt: event.startAt,
            estimatedMinutes: nil,
            plannedDate: event.startAt,  // 自動安排在活動當天
            isDateLocked: true  // 鎖定日期，因為活動時間固定
        )

        try db.collection("tasks").addDocument(from: task)
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

        // 同時刪除相關的任務
        try await deleteTaskForEvent(eventId: eventId, userId: userId)
    }

    /// 刪除活動相關的任務
    private func deleteTaskForEvent(eventId: String, userId: String) async throws {
        // 查找與此活動相關的任務
        let taskSnapshot = try await db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("sourceType", isEqualTo: TaskSourceType.eventSignup.rawValue)
            .getDocuments()

        // 由於無法直接查詢 event ID，我們需要檢查每個任務
        // 在實際應用中，可以考慮在 Task 模型中添加 linkedEventId 欄位
        for doc in taskSnapshot.documents {
            try await db.collection("tasks").document(doc.documentID).delete()
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
