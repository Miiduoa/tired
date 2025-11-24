import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Organization

struct Organization: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var type: OrgType
    var description: String?

    var avatarUrl: String?
    var coverUrl: String?

    var isVerified: Bool
    var createdByUserId: String

    var createdAt: Date
    var updatedAt: Date
    
    // Non-Codable property to hold fetched roles
    var roles: [Role] = []

    enum CodingKeys: String, CodingKey {
        case id, name, type, description, avatarUrl, coverUrl, isVerified, createdByUserId, createdAt, updatedAt
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Organization, rhs: Organization) -> Bool {
        return lhs.id == rhs.id
    }

    init(
        id: String? = nil,
        name: String,
        type: OrgType,
        description: String? = nil,
        avatarUrl: String? = nil,
        coverUrl: String? = nil,
        isVerified: Bool = false,
        createdByUserId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        roles: [Role] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.avatarUrl = avatarUrl
        self.coverUrl = coverUrl
        self.isVerified = isVerified
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.roles = roles
    }
}

// MARK: - Membership

struct Membership: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var organizationId: String

    var roleIds: [String] // REPLACED: role: MembershipRole
    var title: String?  // "大二资管系", "晚班工读生"

    var isPrimaryForType: Bool?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, organizationId, roleIds, title, isPrimaryForType, createdAt, updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        organizationId: String,
        roleIds: [String],
        title: String? = nil,
        isPrimaryForType: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.organizationId = organizationId
        self.roleIds = roleIds
        self.title = title
        self.isPrimaryForType = isPrimaryForType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Membership with Organization (for UI)

struct MembershipWithOrg: Identifiable, Hashable {
    let membership: Membership
    let organization: Organization?

    let id: String // Make id non-optional

    init(membership: Membership, organization: Organization?) {
        self.membership = membership
        self.organization = organization
        self.id = membership.id ?? UUID().uuidString // Provide a fallback UUID
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MembershipWithOrg, rhs: MembershipWithOrg) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Membership Extensions

extension Membership {
    /// 檢查是否有指定權限 (NEW IMPLEMENTATION)
    func hasPermission(_ permission: OrgPermission, in organization: Organization) -> Bool {
        // 1. 從 organization 的 roles 列表中，篩選出此 membership 擁有的角色
        let memberRoles = organization.roles.filter { role in
            guard let roleId = role.id else { return false }
            return self.roleIds.contains(roleId)
        }
        
        // 2. 檢查這些角色中，是否有任何一個包含指定的權限
        for role in memberRoles {
            if role.permissions.contains(permission.rawValue) {
                return true
            }
        }
        
        return false
    }

    /*
    // TODO: Re-implement these functions based on the new dynamic role system.
    // The old logic based on `hierarchyLevel` is no longer valid.
    
    /// 檢查是否可以管理指定成員
    func canManageMember(_ targetMembership: Membership) -> Bool {
        // 不能管理自己
        guard userId != targetMembership.userId else { return false }
        // 只能管理比自己低的角色
        // return role.canManage(targetMembership.role)
        return false // Placeholder
    }

    /// 檢查是否可以變更到指定角色
    func canChangeRoleTo(_ targetRole: MembershipRole) -> Bool {
        // 只有owner可以設定owner
        if targetRole == .owner {
            // return role == .owner
        }
        // 只能設定比自己低的角色
        // return role.canManage(targetRole)
        return false // Placeholder
    }
    */
}

// MARK: - Member with Profile (for UI)

struct MemberWithProfile: Identifiable {
    let membership: Membership
    let userProfile: UserProfile?

    var id: String? { membership.id }

    var displayName: String {
        userProfile?.name ?? "未知用戶"
    }

    var avatarUrl: String? {
        userProfile?.avatarUrl
    }
}
