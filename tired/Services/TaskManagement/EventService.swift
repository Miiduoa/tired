import Foundation
import FirebaseFirestore

// MARK: - Event Service
@MainActor
class EventService: BaseFirestoreService, ObservableObject {

    static let shared = EventService()

    private let COLLECTION = "events"
    private let LINKS_COLLECTION = "event_task_links"

    @Published var events: [Event] = []

    // MARK: - CRUD Operations

    func createEvent(_ event: Event) async throws {
        var newEvent = event
        newEvent.createdAt = Date()
        newEvent.updatedAt = Date()

        // Set denormalized date fields
        newEvent.startDate = DateUtils.formatDateKey(newEvent.startAt)
        newEvent.endDate = DateUtils.formatDateKey(newEvent.endAt)

        try await create(newEvent, collection: COLLECTION)
    }

    func updateEvent(_ event: Event) async throws {
        var updatedEvent = event
        updatedEvent.updatedAt = Date()

        // Update denormalized date fields
        updatedEvent.startDate = DateUtils.formatDateKey(updatedEvent.startAt)
        updatedEvent.endDate = DateUtils.formatDateKey(updatedEvent.endAt)

        try await update(updatedEvent, collection: COLLECTION)

        // Handle linked tasks
        try await handleEventTimeChange(eventId: updatedEvent.id, newStartAt: updatedEvent.startAt)
    }

    func getEvent(id: String) async throws -> Event? {
        return try await read(id: id, collection: COLLECTION, as: Event.self)
    }

    func deleteEvent(id: String) async throws {
        // Mark all links as not auto-sync
        try await handleEventDeleted(eventId: id)

        // Delete the event
        try await hardDelete(id: id, collection: COLLECTION)
    }

    // MARK: - Query Events

    func getEvents(userId: String, startDate: String, endDate: String) async throws -> [Event] {
        return try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .lessThanOrEquals(field: "startDate", value: endDate),
                .greaterThanOrEquals(field: "endDate", value: startDate)
            ],
            as: Event.self
        )
    }

    func getEventsForDate(userId: String, date: Date) async throws -> [Event] {
        let dateKey = DateUtils.formatDateKey(date)
        return try await getEvents(userId: userId, startDate: dateKey, endDate: dateKey)
    }

    func getEventsForWeek(userId: String, weekStart: Date) async throws -> [Event] {
        let weekEnd = DateUtils.addDays(weekStart, 6)
        let startKey = DateUtils.formatDateKey(weekStart)
        let endKey = DateUtils.formatDateKey(weekEnd)

        return try await getEvents(userId: userId, startDate: startKey, endDate: endKey)
    }

    // MARK: - Event Task Links

    func createLink(_ link: EventTaskLink) async throws {
        try await create(link, collection: LINKS_COLLECTION)
    }

    func getLinksForEvent(eventId: String) async throws -> [EventTaskLink] {
        return try await query(
            collection: LINKS_COLLECTION,
            filters: [.equals(field: "eventId", value: eventId)],
            as: EventTaskLink.self
        )
    }

    func getLinksForTask(taskId: String) async throws -> [EventTaskLink] {
        return try await query(
            collection: LINKS_COLLECTION,
            filters: [.equals(field: "taskId", value: taskId)],
            as: EventTaskLink.self
        )
    }

    func updateLink(_ link: EventTaskLink) async throws {
        try await update(link, collection: LINKS_COLLECTION)
    }

    func deleteLink(linkId: String) async throws {
        try await hardDelete(id: linkId, collection: LINKS_COLLECTION)
    }

    // MARK: - Link Management

    private func handleEventTimeChange(eventId: String, newStartAt: Date) async throws {
        let links = try await getLinksForEvent(eventId: eventId)

        for link in links where link.autoSyncDeadline {
            // Update task deadline
            if let task = try await TaskService.shared.getTask(id: link.taskId),
               task.state == .open {
                try await TaskService.shared.setDeadline(task, deadline: newStartAt)

                // If it's an exam prep task, recalculate all session deadlines
                if task.isExamPrep, let groupId = task.examPrepGroupId {
                    // TODO: Implement exam prep group deadline recalculation
                }
            }
        }
    }

    private func handleEventDeleted(eventId: String) async throws {
        let links = try await getLinksForEvent(eventId: eventId)

        for link in links {
            // Disable auto sync
            var updatedLink = link
            updatedLink.autoSyncDeadline = false
            try await updateLink(updatedLink)

            // Mark exam prep tasks
            if let task = try await TaskService.shared.getTask(id: link.taskId),
               task.isExamPrep {
                var updatedTask = task
                updatedTask.examEventDeleted = true
                try await TaskService.shared.updateTask(updatedTask)
            }
        }
    }

    // MARK: - Busy Time Calculation

    func calculateBusyTime(events: [Event], on date: Date, timeZone: TimeZone = .current) -> Int {
        return CapacityCalculator.busyMin(on: date, events: events, timeZone: timeZone)
    }
}
