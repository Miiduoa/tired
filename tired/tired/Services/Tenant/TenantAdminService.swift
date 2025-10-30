import Foundation
import FirebaseFirestore
import Combine

struct TenantMember: Identifiable, Codable, Hashable {
    let id: String // uid
    let displayName: String
    let email: String
    var role: TenantMembership.Role
}

protocol TenantAdminServiceProtocol {
    func listMembers(groupId: String) async -> [TenantMember]
    func updateRole(groupId: String, uid: String, role: TenantMembership.Role) async throws
    func inviteMember(groupId: String, email: String, role: TenantMembership.Role) async throws
}

final class TenantAdminService: TenantAdminServiceProtocol {
    private let db = Firestore.firestore()

    func listMembers(groupId: String) async -> [TenantMember] {
        do {
            let snap = try await db.collection("groups").document(groupId).collection("members").getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                let uid = data["uid"] as? String ?? doc.documentID
                let display = data["displayName"] as? String ?? (data["email"] as? String ?? "User")
                let email = data["email"] as? String ?? ""
                let roleRaw = data["role"] as? String ?? "member"
                let role = TenantMembership.Role(rawValue: roleRaw) ?? .member
                return TenantMember(id: uid, displayName: display, email: email, role: role)
            }
        } catch {
            return []
        }
    }

    func updateRole(groupId: String, uid: String, role: TenantMembership.Role) async throws {
        let ref = db.collection("groups").document(groupId).collection("members").document(uid)
        try await ref.setData(["role": role.rawValue], merge: true)
    }

    func inviteMember(groupId: String, email: String, role: TenantMembership.Role) async throws {
        // For demo: write an invite document under group
        let ref = db.collection("groups").document(groupId).collection("invites").document()
        try await ref.setData([
            "email": email,
            "role": role.rawValue,
            "createdAt": Timestamp(date: Date())
        ])
    }
}

