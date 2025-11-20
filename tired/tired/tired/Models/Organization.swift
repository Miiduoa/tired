import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Organization

struct Organization: Codable, Identifiable {
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case description
        case avatarUrl
        case coverUrl
        case isVerified
        case createdByUserId
        case createdAt
        case updatedAt
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
        updatedAt: Date = Date()
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
    }
}

// MARK: - Membership

struct Membership: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var organizationId: String

    var role: MembershipRole
    var title: String?  // "大二资管系", "晚班工读生"

    var isPrimaryForType: Bool?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case organizationId
        case role
        case title
        case isPrimaryForType
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        organizationId: String,
        role: MembershipRole,
        title: String? = nil,
        isPrimaryForType: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.organizationId = organizationId
        self.role = role
        self.title = title
        self.isPrimaryForType = isPrimaryForType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Membership with Organization (for UI)

struct MembershipWithOrg: Identifiable {
    let membership: Membership
    let organization: Organization?

    var id: String? { membership.id }
}

// MARK: - Membership Extensions

extension Membership {
    /// 檢查是否有指定權限
    func hasPermission(_ permission: OrgPermission) -> Bool {
        return role.hasPermission(permission)
    }

    /// 檢查是否可以管理指定成員
    func canManageMember(_ targetMembership: Membership) -> Bool {
        // 不能管理自己
        guard userId != targetMembership.userId else { return false }
        // 只能管理比自己低的角色
        return role.canManage(targetMembership.role)
    }

    /// 檢查是否可以變更到指定角色
    func canChangeRoleTo(_ targetRole: MembershipRole) -> Bool {
        // 只有owner可以設定owner
        if targetRole == .owner {
            return role == .owner
        }
        // 只能設定比自己低的角色
        return role.canManage(targetRole)
    }
}

// MARK: - Member with Profile (for UI)

struct MemberWithProfile: Identifiable {
    let membership: Membership
    let userProfile: UserProfile?

    var id: String? { membership.id }

    var displayName: String {
        userProfile?.displayName ?? "未知用戶"
    }

    var avatarUrl: String? {
        userProfile?.avatarUrl
    }
}
