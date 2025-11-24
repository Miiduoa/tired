import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

class PermissionService {
    private let organizationService: OrganizationService
    private let db = FirebaseManager.shared.db

    init(organizationService: OrganizationService = OrganizationService()) {
        self.organizationService = organizationService
    }

    /// 檢查用戶在特定組織中是否擁有某個權限
    /// - Parameters:
    ///   - userId: 用戶ID
    ///   - organizationId: 組織ID
    ///   - permission: 需要檢查的權限字串
    /// - Returns: 如果用戶擁有該權限則為 true，否則為 false
    func hasPermission(userId: String, organizationId: String, permission: String) async throws -> Bool {
        guard !userId.isEmpty && !organizationId.isEmpty else { return false }

        // 1. 獲取用戶在該組織中的成員身份
        let membershipsSnapshot = try await db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        
        guard let membershipDoc = membershipsSnapshot.documents.first,
              let membership = try? membershipDoc.data(as: Membership.self) else {
            return false // 用戶不是該組織的成員
        }

        // 2. 獲取成員身份中所有的角色ID
        let roleIds = membership.roleIds
        guard !roleIds.isEmpty else { return false }

        // 3. 獲取所有相關角色 (從組織的 'roles' 子集合中)
        // 為了效率，可以考慮快取組織的角色資訊
        let organizationRolesSnapshot = try await db.collection("organizations").document(organizationId).collection("roles")
            .whereField(FieldPath.documentID(), in: roleIds)
            .getDocuments()
        
        let roles = organizationRolesSnapshot.documents.compactMap { try? $0.data(as: Role.self) }
        guard !roles.isEmpty else { return false }

        // 4. 檢查是否有任何一個角色擁有該權限
        return roles.contains { $0.permissions.contains(permission) }
    }

    /// 檢查當前登入用戶在特定組織中是否擁有某個權限
    /// - Parameters:
    ///   - organizationId: 組織ID
    ///   - permission: 需要檢查的權限字串
    /// - Returns: 如果當前用戶擁有該權限則為 true，否則為 false
    func hasPermissionForCurrentUser(organizationId: String, permission: String) async throws -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false // 用戶未登入
        }
        return try await hasPermission(userId: currentUserId, organizationId: organizationId, permission: permission)
    }
    
    /// 檢查當前登入用戶是否為組織的擁有者
    /// - Parameter organizationId: 組織ID
    /// - Returns: 如果是擁有者則為 true，否則為 false
    func isOrganizationOwner(organizationId: String) async throws -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false // 用戶未登入
        }
        let organization = try await organizationService.fetchOrganization(id: organizationId)
        return organization.createdByUserId == currentUserId
    }
}
