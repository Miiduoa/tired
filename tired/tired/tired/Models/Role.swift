import Foundation
import FirebaseFirestoreSwift

/// 代表一個組織內的自訂角色
struct Role: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var permissions: [String]
    
    /// 是否為組織的預設角色 (不可刪除)
    var isDefault: Bool? = false
    
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Role, rhs: Role) -> Bool {
        lhs.id == rhs.id
    }
}
