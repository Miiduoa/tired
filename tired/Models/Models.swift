
import Foundation

// 簡化的資料模型（Demo）
struct Broadcast: Identifiable {
    var id = UUID()
    var title: String
    var body: String
    var deadline: Date?
}

struct AttendanceSession: Identifiable {
    var id = UUID()
    var course: String
    var place: String
    var openAt: Date
    var closeAt: Date
}
