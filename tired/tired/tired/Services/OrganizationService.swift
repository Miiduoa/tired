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
        print("🚀 Starting createOrganization...")
        var newOrg = org
        newOrg.createdAt = Date()
        newOrg.updatedAt = Date()
        
        // 1. 生成文檔引用 (不立即寫入)
        let orgRef = db.collection("organizations").document()
        let orgId = orgRef.documentID
        
        let membershipRef = db.collection("memberships").document()
        let membershipId = membershipRef.documentID
        
        let rolesCollection = orgRef.collection("roles")
        let ownerRoleRef = rolesCollection.document()
        let adminRoleRef = rolesCollection.document()
        let memberRoleRef = rolesCollection.document()
        
        // 2. 準備數據
        // 注意：初始化時 id 傳入 nil，因為使用 batch.setData 指定了 document reference，
        // Firestore 會自動關聯 ID。傳入非 nil 的 @DocumentID 屬性會導致警告。
        let ownerPermissions = OrgPermission.allCases.map { $0.permissionString }
        let ownerRole = Role(id: nil, name: "擁有者", permissions: ownerPermissions, isDefault: true)
        
        let adminPermissions = OrgPermission.allCases.filter {
            switch $0 {
            case .deleteOrganization, .transferOwnership: return false
            default: return true
            }
        }.map { $0.permissionString }
        let adminRole = Role(id: nil, name: "管理員", permissions: adminPermissions, isDefault: true)
        
        let memberPermissions: [OrgPermission] = [.viewContent, .comment, .joinEvents, .react]
        let memberRole = Role(id: nil, name: "成員", permissions: memberPermissions.map { $0.permissionString }, isDefault: true)
        
        let initialMembership = Membership(
            id: nil,
            userId: org.createdByUserId,
            organizationId: orgId,
            roleIds: [ownerRoleRef.documentID], // 直接賦予 Owner 角色
            isPrimaryForType: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 確保 newOrg 的 id 為 nil
        var cleanOrg = newOrg
        cleanOrg.id = nil
        
        // 3. 執行批次寫入 (原子性)
        let batch = db.batch()
        
        try batch.setData(from: cleanOrg, forDocument: orgRef)
        try batch.setData(from: initialMembership, forDocument: membershipRef)
        try batch.setData(from: ownerRole, forDocument: ownerRoleRef)
        try batch.setData(from: adminRole, forDocument: adminRoleRef)
        try batch.setData(from: memberRole, forDocument: memberRoleRef)
        
        do {
            print("⏳ Committing batch...")
            try await batch.commit()
            print("✅ Batch committed successfully")
        } catch {
            print("❌ Failed createOrganization batch commit: \(error)")
            throw error
        }
        
        // 4. 非關鍵後續操作 (不需要等待)
        // Use Task.detached to ensure this runs in the background and doesn't inherit the current actor context
        _Concurrency.Task.detached(priority: .utility) {
            // 創建組織聊天室 - 需要設置 id 以便 ChatService 使用
            var orgWithId = newOrg
            orgWithId.id = orgId
            do {
                _ = try await ChatService.shared.getOrCreateOrganizationChatRoom(for: orgWithId)
            } catch {
                print("⚠️ Failed to create chat room (non-fatal): \(error)")
            }
            
            // 根據組織類型創建預設應用
            if newOrg.type == .school {
                let defaultApps: [OrgAppTemplateKey] = [.courseSchedule, .assignmentBoard, .bulletinBoard, .rollCall, .gradebook]
                let db = FirebaseManager.shared.db
                let appsCollection = db.collection("orgAppInstances")
                for appKey in defaultApps {
                    let appInstance = OrgAppInstance(
                        organizationId: orgId,
                        templateKey: appKey,
                        name: appKey.displayName,
                        isEnabled: true
                    )
                    let _ = try? appsCollection.addDocument(from: appInstance)
                }
            }
        }
        
        return orgId
    }
    
    /// 更新組織信息
    func updateOrganization(_ org: Organization) async throws {
        guard let orgId = org.id else {
            throw NSError(domain: "OrganizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Organization ID is missing"])
        }
        
        var updatedOrg = org
        updatedOrg.updatedAt = Date()
        
        try db.collection("organizations").document(orgId).setData(from: updatedOrg, merge: true)
        
        // 清除快取
        organizationCache.removeValue(forKey: orgId)
    }
    
    /// 刪除組織（只有擁有者可以刪除）
    func deleteOrganization(organizationId: String, userId: String) async throws {
        // 1. 權限檢查：只有擁有者可以刪除組織
        let canDelete = try await checkPermission(userId: userId, organizationId: organizationId, permission: .deleteOrganization)
        guard canDelete else {
            throw NSError(domain: "OrganizationService", code: -10, userInfo: [NSLocalizedDescriptionKey: "權限不足：只有組織擁有者才能刪除組織。"])
        }
        
        // 2. 獲取組織以確認
        let organization = try await fetchOrganization(id: organizationId)
        guard organization.createdByUserId == userId else {
            throw NSError(domain: "OrganizationService", code: -11, userInfo: [NSLocalizedDescriptionKey: "權限不足：只有組織創建者才能刪除組織。"])
        }
        
        // 3. 刪除組織及其所有子集合（使用批次操作）
        let batch = db.batch()
        
        // 刪除所有成員資格
        let membershipsSnapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        for doc in membershipsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 刪除所有角色
        let rolesSnapshot = try await db.collection("organizations").document(organizationId).collection("roles").getDocuments()
        for doc in rolesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 刪除所有成員申請
        let requestsSnapshot = try await db.collection("membershipRequests")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        for doc in requestsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 刪除所有小應用實例
        let appsSnapshot = try await db.collection("orgAppInstances")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        for doc in appsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 刪除組織本身
        batch.deleteDocument(db.collection("organizations").document(organizationId))
        
        // 提交批次操作
        try await batch.commit()
        
        // 清除快取
        organizationCache.removeValue(forKey: organizationId)
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
        try db.collection("organizations").document(orgId).collection("roles").document(roleId).setData(from: role)
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
        
        let orgRef = db.collection("organizations").document(organizationId)

        // 2. 獲取角色ID
        let roles = try await orgRef.collection("roles").getDocuments()
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
        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            // 降級原擁有者：移除Owner角色，賦予Admin角色
            transaction.updateData(["roleIds": [adminRoleId], "updatedAt": FieldValue.serverTimestamp()], forDocument: fromMembershipRef)
            // 升級新擁有者：賦予Owner角色
            transaction.updateData(["roleIds": [ownerRoleId], "updatedAt": FieldValue.serverTimestamp()], forDocument: toMembershipRef)
            // 更新組織創建者，確保新擁有者擁有完整的管理權限
            transaction.updateData([
                "createdByUserId": toUserId,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: orgRef)
            return nil
        }
        
        // 清除組織快取以反映角色變化
        organizationCache.removeValue(forKey: organizationId)
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
            try? await ChatService.shared.removeUserFromOrganizationChatRoom(userId: membership.userId, organizationId: membership.organizationId)
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
            try? await ChatService.shared.removeUserFromOrganizationChatRoom(userId: membership.userId, organizationId: membership.organizationId)
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
        try? await ChatService.shared.removeUserFromOrganizationChatRoom(userId: membership.userId, organizationId: membership.organizationId)
        try await deleteMembership(id: membershipId)
        print("✅ Ownership transfer complete and original owner's membership removed.")
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

        // 4. 將用戶加入聊天室
        try? await ChatService.shared.addUserToOrganizationChatRoom(userId: request.userId, organizationId: request.organizationId)
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

    // MARK: - Invitations

    /// 建立邀請
    func createInvitation(organizationId: String, inviterId: String, roleIds: [String], maxUses: Int? = nil, expirationHours: Int? = nil) async throws -> Invitation {
        // 1. 權限檢查
        let canInvite = try await checkPermission(userId: inviterId, organizationId: organizationId, permission: .manageMembers)
        guard canInvite else {
            throw NSError(domain: "OrganizationService", code: -10, userInfo: [NSLocalizedDescriptionKey: "權限不足：您沒有權限邀請成員。"])
        }

        var expirationDate: Date?
        if let hours = expirationHours {
            expirationDate = Calendar.current.date(byAdding: .hour, value: hours, to: Date())
        }
        
        // 產生 8 碼大寫英數混合代碼
        let code = String(UUID().uuidString.prefix(8)).uppercased()

        let invitation = Invitation(
            organizationId: organizationId,
            inviterId: inviterId,
            code: code,
            roleIds: roleIds,
            expirationDate: expirationDate,
            maxUses: maxUses
        )
        
        let ref = try db.collection("invitations").addDocument(from: invitation)
        var newInvitation = invitation
        newInvitation.id = ref.documentID
        return newInvitation
    }

    /// 獲取組織的有效邀請
    func fetchInvitations(organizationId: String) async throws -> [Invitation] {
        let snapshot = try await db.collection("invitations")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
            
        return snapshot.documents.compactMap { doc -> Invitation? in
            try? doc.data(as: Invitation.self)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    /// 刪除邀請
    func deleteInvitation(id: String) async throws {
        try await db.collection("invitations").document(id).delete()
    }

    /// 透過邀請碼加入組織
    func joinByInvitationCode(code: String, userId: String) async throws -> String {
        // 1. 查找邀請碼
        let snapshot = try await db.collection("invitations")
            .whereField("code", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
            
        guard let doc = snapshot.documents.first,
              let invitation = try? doc.data(as: Invitation.self),
              let invitationId = invitation.id else {
            throw NSError(domain: "OrganizationService", code: -20, userInfo: [NSLocalizedDescriptionKey: "無效的邀請碼。"])
        }
        
        // 2. 檢查是否已是成員
        let existingMember = try await db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: invitation.organizationId)
            .getDocuments()
            
        if !existingMember.isEmpty {
            throw NSError(domain: "OrganizationService", code: -22, userInfo: [NSLocalizedDescriptionKey: "您已經是該組織的成員。"])
        }
        
        // 3. 執行加入邏輯 (Transaction) 並再次驗證有效性與使用次數，避免競態條件
        let orgId = invitation.organizationId        
        let invRef = self.db.collection("invitations").document(invitationId)
        
        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let freshSnapshot = try transaction.getDocument(invRef)
                guard var freshInvitation = try? freshSnapshot.data(as: Invitation.self) else {
                    throw NSError(domain: "OrganizationService", code: -23, userInfo: [NSLocalizedDescriptionKey: "邀請碼資料異常。"])
                }
                
                // 使用最新數據重新驗證有效性
                guard freshInvitation.isActive else {
                    throw NSError(domain: "OrganizationService", code: -21, userInfo: [NSLocalizedDescriptionKey: "邀請碼已過期或失效。"])
                }
                
                // 檢查使用次數是否已達上限（再次檢查避免併發超用）
                if let maxUses = freshInvitation.maxUses, freshInvitation.currentUses >= maxUses {
                    throw NSError(domain: "OrganizationService", code: -21, userInfo: [NSLocalizedDescriptionKey: "邀請碼已達最大使用次數。"])
                }
                
                // 更新使用次數
                freshInvitation.currentUses += 1
                transaction.updateData([
                    "currentUses": freshInvitation.currentUses,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: invRef)
                
                // 建立成員資格
                let newMembershipRef = self.db.collection("memberships").document()
                let newMembership = Membership(
                    userId: userId,
                    organizationId: orgId,
                    roleIds: freshInvitation.roleIds,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let _ = try? transaction.setData(from: newMembership, forDocument: newMembershipRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            return nil
        }
        
        // 5. 加入聊天室
        try? await ChatService.shared.addUserToOrganizationChatRoom(userId: userId, organizationId: orgId)
        
        return orgId
    }
}
