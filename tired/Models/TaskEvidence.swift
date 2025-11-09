import Foundation
import FirebaseFirestore

struct TaskEvidence: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: EvidenceType
    var title: String
    var url: String?
    var fileId: String?
    var note: String?

    enum EvidenceType: String, Codable {
        case link
        case file
        case note
    }
}
