import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 代表一個成員資格的邀請或申請
struct MembershipRequest: Codable, Identifiable {
    @DocumentID var id: String?
    let organizationId: String
    let userId: String
    let userName: String // 顯示在審核列表中的使用者名稱
    var status: RequestStatus
    let type: RequestType
    let createdAt: Timestamp

    enum RequestStatus: String, Codable {
        case pending
        case approved
        case rejected
    }

    enum RequestType: String, Codable {
        case invite // 組織邀請使用者
        case request // 使用者申請加入
    }
}
