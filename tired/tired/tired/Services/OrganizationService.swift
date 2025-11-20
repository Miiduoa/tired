import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 组织和身份管理服务
class OrganizationService: ObservableObject {
    private let db = FirebaseManager.shared.db

    // MARK: - Organizations

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
                        let org = try? await self.fetchOrganization(id: membership.organizationId)
                        results.append(MembershipWithOrg(membership: membership, organization: org))
                    }

                    subject.send(results)
                }
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取单个组织
    func fetchOrganization(id: String) async throws -> Organization {
        let document = try await db.collection("organizations").document(id).getDocument()
        return try document.data(as: Organization.self)
    }

    /// 创建组织
    func createOrganization(_ org: Organization) async throws -> String {
        var newOrg = org
        newOrg.createdAt = Date()
        newOrg.updatedAt = Date()

        let ref = try db.collection("organizations").addDocument(from: newOrg)
        return ref.documentID
    }

    // MARK: - Memberships

    /// 创建身份（加入组织）
    func createMembership(_ membership: Membership) async throws {
        var newMembership = membership
        newMembership.createdAt = Date()
        newMembership.updatedAt = Date()

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

    /// 變更成員角色
    func changeMemberRole(membershipId: String, newRole: MembershipRole) async throws {
        let updates: [String: Any] = [
            "role": newRole.rawValue,
            "updatedAt": Date()
        ]

        try await db.collection("memberships")
            .document(membershipId)
            .updateData(updates)
    }

    /// 轉移組織所有權
    func transferOwnership(organizationId: String, fromUserId: String, toUserId: String) async throws {
        // 1. 找到原owner的membership
        let fromSnapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: fromUserId)
            .whereField("role", isEqualTo: MembershipRole.owner.rawValue)
            .getDocuments()

        guard let fromDoc = fromSnapshot.documents.first else {
            throw NSError(domain: "OrganizationService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "找不到原所有者"])
        }

        // 2. 找到目標用戶的membership
        let toSnapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: toUserId)
            .getDocuments()

        guard let toDoc = toSnapshot.documents.first else {
            throw NSError(domain: "OrganizationService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "目標用戶不是組織成員"])
        }

        // 3. 使用批次操作同時更新
        let batch = db.batch()

        // 將原owner降級為admin
        batch.updateData([
            "role": MembershipRole.admin.rawValue,
            "updatedAt": Date()
        ], forDocument: fromDoc.reference)

        // 將目標用戶升級為owner
        batch.updateData([
            "role": MembershipRole.owner.rawValue,
            "updatedAt": Date()
        ], forDocument: toDoc.reference)

        try await batch.commit()
    }

    /// 當成員離開組織時的繼任處理
    func handleMemberLeave(membership: Membership) async throws {
        // 如果不是owner離開，直接刪除即可
        guard membership.role == .owner else {
            try await deleteMembership(id: membership.id!)
            return
        }

        // Owner離開需要處理繼任
        let members = try await fetchOrganizationMembers(organizationId: membership.organizationId)

        // 找到除了自己之外的所有成員
        let otherMembers = members.filter { $0.userId != membership.userId }

        if otherMembers.isEmpty {
            // 如果是最後一個成員，允許離開（組織會變成無主）
            try await deleteMembership(id: membership.id!)
            return
        }

        // 找到最高層級的成員作為繼任者
        let successor = otherMembers.max { $0.role.hierarchyLevel < $1.role.hierarchyLevel }

        guard let newOwner = successor else {
            throw NSError(domain: "OrganizationService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "找不到繼任者"])
        }

        // 轉移所有權
        try await transferOwnership(
            organizationId: membership.organizationId,
            fromUserId: membership.userId,
            toUserId: newOwner.userId
        )

        // 刪除原owner的membership
        try await deleteMembership(id: membership.id!)
    }

    /// 檢查用戶在組織中的權限
    func checkPermission(userId: String, organizationId: String, permission: OrgPermission) async throws -> Bool {
        let snapshot = try await db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let membership = try? doc.data(as: Membership.self) else {
            return false
        }

        return membership.hasPermission(permission)
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
