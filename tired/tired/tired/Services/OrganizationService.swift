import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 组织和身份管理服务
class OrganizationService: ObservableObject {
    private let db = FirebaseManager.shared.db
    
    // 緩存組織資料
    private var organizationCache: [String: Organization] = [:]

    // MARK: - Organizations
    
    /// 批次獲取組織資料
    func fetchOrganizations(ids: [String]) async throws -> [String: Organization] {
        var orgs: [String: Organization] = [:]
        let uniqueIds = Array(Set(ids.filter { !$0.isEmpty }))
        
        // 優先從快取返回
        for orgId in uniqueIds {
            if let cached = organizationCache[orgId] {
                orgs[orgId] = cached
            }
        }
        
        let uncachedIds = uniqueIds.filter { orgs[$0] == nil }
        
        // 如果沒有需要獲取的，直接返回
        if uncachedIds.isEmpty {
            return orgs
        }
        
        // 對於未快取的 ID，逐一獲取
        // 注意：這會導致 N+1 查詢問題，但在需要獲取子集合時這是常見模式。
        // 未來可考慮將 roles 直接作為陣列存在 org 文件中進行優化。
        for orgId in uncachedIds {
            if let org = try? await fetchOrganization(id: orgId) {
                orgs[orgId] = org
            }
        }
        
        return orgs
    }

    /// 获取用户的所有组织（通过Membership）
    func fetchUserOrganizations(userId: String) -> AnyPublisher<[MembershipWithOrg], Error> {
        let subject = PassthroughSubject<[MembershipWithOrg], Error>()

        db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let memberships = documents.compactMap { doc -> Membership? in
                    try? doc.data(as: Membership.self)
                }

                // 获取每个membership对应的organization
                _Concurrency.Task { [weak self] in
                    guard let self = self else { return }
                    var results: [MembershipWithOrg] = []

                    for membership in memberships {
                        // fetchOrganization 現在會包含 roles
                        let org = try? await self.fetchOrganization(id: membership.organizationId)
                        results.append(MembershipWithOrg(membership: membership, organization: org))
                    }

                    subject.send(results)
                }
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取单个组织 (包含其角色)
    func fetchOrganization(id: String) async throws -> Organization {
        if let cached = organizationCache[id], !cached.roles.isEmpty {
            return cached
        }
        
        let orgRef = db.collection("organizations").document(id)
        
        // 使用 async let 並行獲取組織文件和角色子集合
        async let orgDoc = orgRef.getDocument()
        async let rolesSnapshot = orgRef.collection("roles").getDocuments()

        var organization = try await orgDoc.data(as: Organization.self)
        organization.id = id
        
        let roles = try await rolesSnapshot.documents.compactMap { doc -> Role? in
            var role = try? doc.data(as: Role.self)
            role?.id = doc.documentID
            return role
        }
        organization.roles = roles
        
        // 更新快取
        organizationCache[id] = organization
        
        return organization
    }

    /// 创建组织 (包含預設角色)
    func createOrganization(_ org: Organization) async throws -> String {
        var newOrg = org
        newOrg.createdAt = Date()
        newOrg.updatedAt = Date()

        // 1. 創建組織文件
        let orgRef = try db.collection("organizations").addDocument(from: newOrg)
        let orgId = orgRef.documentID

        // 2. 創建預設角色
        let batch = db.batch()
        let rolesCollection = orgRef.collection("roles")

        // Owner Role
        let ownerRoleRef = rolesCollection.document()
        let ownerPermissions = OrgPermission.allCases.map { $0.permissionString }
        let ownerRole = Role(id: ownerRoleRef.documentID, name: "擁有者", permissions: ownerPermissions, isDefault: true)
        try batch.setData(from: ownerRole, forDocument: ownerRoleRef)

        // Admin Role
        let adminRoleRef = rolesCollection.document()
        let adminPermissions = OrgPermission.allCases.filter {
            switch $0 {
            case .deleteOrganization, .transferOwnership: return false
            default: return true
            }
        }.map { $0.permissionString }
        let adminRole = Role(id: adminRoleRef.documentID, name: "管理員", permissions: adminPermissions, isDefault: true)
        try batch.setData(from: adminRole, forDocument: adminRoleRef)

        // Member Role
        let memberRoleRef = rolesCollection.document()
        let memberPermissions: [OrgPermission] = [.viewContent, .comment, .joinEvents, .react]
        let memberRole = Role(id: memberRoleRef.documentID, name: "成員", permissions: memberPermissions.map { $0.permissionString }, isDefault: true)
        try batch.setData(from: memberRole, forDocument: memberRoleRef)
        
        // 3. 提交批次操作以創建角色
        try await batch.commit()

        // 4. 為創建者添加 Owner 身份
        try await createMembership(
            userId: org.createdByUserId,
            organizationId: orgId,
            roleIds: [ownerRole.id!]
        )
        
        return orgId
    }

    // MARK: - Roles

    /// 為組織新增一個角色
    func addRole(name: String, permissions: [String], toOrganizationId orgId: String) async throws -> String {
        let newRole = Role(name: name, permissions: permissions, isDefault: false)
        let ref = try db.collection("organizations").document(orgId).collection("roles").addDocument(from: newRole)
        
        // 新增角色後，清除該組織的快取，以便下次獲取時能包含新角色
        organizationCache.removeValue(forKey: orgId)
        
        return ref.documentID
    }
    
    /// 更新組織中的一個角色
    func updateRole(_ role: Role, inOrganizationId orgId: String) async throws {
        guard let roleId = role.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Role ID is missing"])
        }
        try await db.collection("organizations").document(orgId).collection("roles").document(roleId).setData(from: role)
        organizationCache.removeValue(forKey: orgId)
    }

    /// 從組織中刪除一個角色
    func deleteRole(_ role: Role, fromOrganizationId orgId: String) async throws {
        guard let roleId = role.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Role ID is missing"])
        }
        guard role.isDefault != true else {
            throw NSError(domain: "OrganizationService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot delete a default role"])
        }

        // 檢查是否有成員仍在使用此角色
        let membersInRoleSnapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: orgId)
            .whereField("roleIds", arrayContains: roleId)
            .limit(to: 1)
            .getDocuments()

        if !membersInRoleSnapshot.isEmpty {
            throw NSError(domain: "OrganizationService", code: -3, userInfo: [NSLocalizedDescriptionKey: "無法刪除：該角色仍有成員正在使用。"])
        }

        // 如果沒有成員使用，則可以安全刪除
        try await db.collection("organizations").document(orgId).collection("roles").document(roleId).delete()
        organizationCache.removeValue(forKey: orgId)
    }

    // MARK: - Memberships

    /// 创建身份（加入组织）
    func createMembership(userId: String, organizationId: String, roleIds: [String]) async throws {
        let newMembership = Membership(
            userId: userId,
            organizationId: organizationId,
            roleIds: roleIds,
            createdAt: Date(),
            updatedAt: Date()
        )
        _ = try db.collection("memberships").addDocument(from: newMembership)
    }

    /// 更新身份
    func updateMembership(_ membership: Membership) async throws {
        guard let id = membership.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Membership ID is missing"])
        }

        var updated = membership
        updated.updatedAt = Date()

        try db.collection("memberships").document(id).setData(from: updated)
    }

    /// 离开组织（删除身份）
    func deleteMembership(id: String) async throws {
        try await db.collection("memberships").document(id).delete()
    }

    /// 獲取組織的所有成員
    func fetchOrganizationMembers(organizationId: String) async throws -> [Membership] {
        let snapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Membership? in
            try? doc.data(as: Membership.self)
        }
    }

    /// 變更成員的角色
    func changeMemberRoles(membershipId: String, newRoleIds: [String]) async throws {
        let updates: [String: Any] = [
            "roleIds": newRoleIds,
            "updatedAt": Date()
        ]

        try await db.collection("memberships")
            .document(membershipId)
            .updateData(updates)
    }

    /// 轉移組織所有權
    func transferOwnership(organizationId: String, fromUserId: String, toUserId: String) async throws {
        // 1. 權限檢查：只有當前擁有者可以轉移所有權
        let canTransfer = try await checkPermission(userId: fromUserId, organizationId: organizationId, permission: .deleteOrganization)
        guard canTransfer else {
            throw NSError(domain: "OrganizationService", code: -10, userInfo: [NSLocalizedDescriptionKey: "權限不足：只有組織擁有者才能轉移所有權。"])
        }

        guard fromUserId != toUserId else {
            throw NSError(domain: "OrganizationService", code: -11, userInfo: [NSLocalizedDescriptionKey: "無效操作：無法將所有權轉移給自己。"])
        }

        // 2. 獲取角色ID
        let roles = try await db.collection("organizations").document(organizationId).collection("roles").getDocuments()
        guard let ownerRole = roles.documents.first(where: { ($0["name"] as? String) == "擁有者" }),
              let adminRole = roles.documents.first(where: { ($0["name"] as? String) == "管理員" }) else {
            throw NSError(domain: "OrganizationService", code: -12, userInfo: [NSLocalizedDescriptionKey: "找不到必要的角色（擁有者/管理員）。"])
        }
        let ownerRoleId = ownerRole.documentID
        let adminRoleId = adminRole.documentID

        // 3. 獲取雙方成員資格
        async let fromMembershipDoc = db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: fromUserId).getDocuments()
        async let toMembershipDoc = db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: toUserId).getDocuments()

        guard let fromMembershipSnapshot = try await fromMembershipDoc.documents.first,
              let toMembershipSnapshot = try await toMembershipDoc.documents.first else {
            throw NSError(domain: "OrganizationService", code: -13, userInfo: [NSLocalizedDescriptionKey: "找不到轉移雙方的成員資格。"])
        }
        
        let fromMembershipRef = fromMembershipSnapshot.reference
        let toMembershipRef = toMembershipSnapshot.reference

        // 4. 使用事務執行原子性操作
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            // 降級原擁有者：移除Owner角色，賦予Admin角色
            transaction.updateData(["roleIds": [adminRoleId], "updatedAt": FieldValue.serverTimestamp()], forDocument: fromMembershipRef)
            // 升級新擁有者：賦予Owner角色
            transaction.updateData(["roleIds": [ownerRoleId], "updatedAt": FieldValue.serverTimestamp()], forDocument: toMembershipRef)
            return nil
        }
        
        // 清除組織快取以反映角色變化
        organizationCache.removeValue(forKey: organizationId)
    }

    /// 當成員離開組織時的繼任處理
    func handleMemberLeave(membership: Membership) async throws {
        // ... Omitted for now ...
    }

    // MARK: - Membership Requests

    /// 創建成員資格申請/邀請
    func createMembershipRequest(organizationId: String, userId: String, userName: String, type: MembershipRequest.RequestType) async throws {
        // 先檢查是否已經有正在等待的申請
        let existingRequest = try await db.collection("membershipRequests")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: MembershipRequest.RequestStatus.pending.rawValue)
            .getDocuments()

        guard existingRequest.documents.isEmpty else {
            // 如果已有正在等待的申請，則不重複建立
            print("ℹ️ User already has a pending request for this organization.")
            return
        }
        
        let request = MembershipRequest(
            organizationId: organizationId,
            userId: userId,
            userName: userName,
            status: .pending,
            type: type,
            createdAt: Timestamp()
        )
        
        _ = try db.collection("membershipRequests").addDocument(from: request)
    }

    /// 批准成員資格申請
    func approveMembershipRequest(request: MembershipRequest) async throws {
        guard let requestId = request.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request ID is missing"])
        }

        // 1. 找到該組織的預設 "成員" 角色
        let memberRoleSnapshot = try await db.collection("organizations").document(request.organizationId).collection("roles")
            .whereField("name", isEqualTo: "成員")
            .limit(to: 1)
            .getDocuments()

        guard let memberRoleDoc = memberRoleSnapshot.documents.first else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Default 'Member' role not found"])
        }
        let memberRoleId = memberRoleDoc.documentID
        
        // 2. 使用批次操作來確保原子性
        let batch = db.batch()

        // 2a. 更新申請單狀態
        let requestRef = db.collection("membershipRequests").document(requestId)
        batch.updateData(["status": MembershipRequest.RequestStatus.approved.rawValue], forDocument: requestRef)

        // 2b. 創建新的成員資格
        let newMembership = Membership(
            userId: request.userId,
            organizationId: request.organizationId,
            roleIds: [memberRoleId]
        )
        let membershipRef = db.collection("memberships").document()
        try batch.setData(from: newMembership, forDocument: membershipRef)
        
        // 3. 提交批次操作
        try await batch.commit()
    }

    /// 拒絕成員資格申請
    func rejectMembershipRequest(request: MembershipRequest) async throws {
        guard let requestId = request.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request ID is missing"])
        }
        
        try await db.collection("membershipRequests").document(requestId).updateData([
            "status": MembershipRequest.RequestStatus.rejected.rawValue
        ])
    }

    /// 當成員離開組織時的繼任處理
    func handleMemberLeave(membership: Membership) async throws {
        guard let membershipId = membership.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Membership ID is missing"])
        }

        // 1. 獲取組織以進行權限檢查
        let organization = try await fetchOrganization(id: membership.organizationId)

        // 2. 檢查離開者是否為 Owner
        let isOwnerLeaving = membership.isOwner(in: organization)

        if !isOwnerLeaving {
            // 如果不是 Owner，直接刪除其成員資格
            try await deleteMembership(id: membershipId)
            return
        }

        // --- 以下為 Owner 離開時的繼任邏輯 ---

        // 3. 獲取組織內所有其他成員
        var otherMembers = try await fetchOrganizationMembers(organizationId: membership.organizationId)
        otherMembers.removeAll { $0.userId == membership.userId }

        // 如果沒有其他成員，組織將變為無主，直接刪除原 Owner
        guard let successorMembership = findSuccessor(from: otherMembers, in: organization) else {
            print("ℹ️ Owner is the last member. Organization \(organization.id ?? "") will become ownerless.")
            try await deleteMembership(id: membershipId)
            return
        }

        // 5. 執行所有權轉移
        print("ℹ️ Transferring ownership from \(membership.userId) to \(successorMembership.userId)")
        try await transferOwnership(
            organizationId: membership.organizationId,
            fromUserId: membership.userId,
            toUserId: successorMembership.userId
        )

        // 6. 刪除原 Owner 的成員資格
        try await deleteMembership(id: membershipId)
        print("✅ Ownership transfer complete and original owner's membership removed.")
    }

    /// 從候選人中尋找繼任者
    private func findSuccessor(from candidates: [Membership], in organization: Organization) -> Membership? {
        if candidates.isEmpty {
            return nil
        }
        
        // 優先選擇管理員
        var admins = candidates.filter { $0.isAdmin(in: organization) }
        
        // 如果有管理員，選擇最早加入的
        if !admins.isEmpty {
            admins.sort { $0.createdAt < $1.createdAt }
            return admins.first
        }
        
        // 如果沒有管理員，選擇最早加入的成員
        var sortedCandidates = candidates
        sortedCandidates.sort { $0.createdAt < $1.createdAt }
        return sortedCandidates.first
    }


    /// 檢查用戶在組織中的權限
    func checkPermission(userId: String, organizationId: String, permission: OrgPermission) async throws -> Bool {
        // 1. 獲取組織 (它會包含所有角色)
        let organization = try await fetchOrganization(id: organizationId)
        
        // 2. 獲取用戶在該組織的成員資格
        let snapshot = try await db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let membership = try? doc.data(as: Membership.self) else {
            // 如果找不到成員資格，代表沒有權限
            return false
        }

        // 3. 使用新的 hasPermission 方法進行檢查
        return membership.hasPermission(permission, in: organization)
    }

    /// 按类别获取身份（例如：所有学校身份）
    func fetchMembershipsByOrgType(userId: String, orgType: OrgType) async throws -> [MembershipWithOrg] {
        // 先获取所有membership
        let snapshot = try await db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let memberships = snapshot.documents.compactMap { doc -> Membership? in
            try? doc.data(as: Membership.self)
        }

        // 获取对应的organizations并过滤
        var results: [MembershipWithOrg] = []

        for membership in memberships {
            if let org = try? await fetchOrganization(id: membership.organizationId),
               org.type == orgType {
                results.append(MembershipWithOrg(membership: membership, organization: org))
            }
        }

        return results
    }
}
