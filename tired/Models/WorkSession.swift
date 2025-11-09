import Foundation
import FirebaseFirestore

struct WorkSession: Codable, Identifiable {
    var id: String = UUID().uuidString
    var startAt: Date
    var endAt: Date
    var durationMin: Int
    var pomodoroCount: Int
    var breakSessions: Int
    var wasInterrupted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case startAt = "start_at"
        case endAt = "end_at"
        case durationMin = "duration_min"
        case pomodoroCount = "pomodoro_count"
        case breakSessions = "break_sessions"
        case wasInterrupted = "was_interrupted"
    }
}
