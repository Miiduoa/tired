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
