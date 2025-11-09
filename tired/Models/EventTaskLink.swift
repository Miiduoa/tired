import Foundation
import FirebaseFirestore

struct EventTaskLink: Codable, Identifiable {
    var id: String { "\(eventId)_\(taskId)" }
    var eventId: String
    var taskId: String
    var autoSyncDeadline: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case taskId = "task_id"
        case autoSyncDeadline = "auto_sync_deadline"
        case createdAt = "created_at"
    }

    init(eventId: String, taskId: String, autoSyncDeadline: Bool = true) {
        self.eventId = eventId
        self.taskId = taskId
        self.autoSyncDeadline = autoSyncDeadline
        self.createdAt = Date()
    }
}
