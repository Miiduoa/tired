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
    
    // MARK: - Course/Organization Enhancement (Moodle-like features)
    
    // 課程相關屬性（僅當 type 為 school 或 department 時使用）
    var courseCode: String?              // 課程代碼（例如："CS101"）
    var semester: String?                // 學期（例如："2024-1" 表示 2024 學年第一學期）
    var credits: Int?                    // 學分數
    var syllabus: String?                // 課程大綱（Markdown 格式）
    var schedule: [CourseSchedule]?       // 課程時間表（不直接存儲，通過子集合獲取）
    var academicYear: String?            // 學年（例如："2024"）
    var courseLevel: String?              // 課程級別（例如："大學部", "研究所"）
    var prerequisites: [String]?          // 先修課程 ID 列表
    var maxEnrollment: Int?              // 最大選課人數
    var currentEnrollment: Int?          // 目前選課人數

    enum CodingKeys: String, CodingKey {
        case id, name, type, description, avatarUrl, coverUrl, isVerified, createdByUserId, createdAt, updatedAt
        case courseCode, semester, credits, syllabus, academicYear, courseLevel, prerequisites, maxEnrollment, currentEnrollment
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
        roles: [Role] = [],
        courseCode: String? = nil,
        semester: String? = nil,
        credits: Int? = nil,
        syllabus: String? = nil,
        schedule: [CourseSchedule]? = nil,
        academicYear: String? = nil,
        courseLevel: String? = nil,
        prerequisites: [String]? = nil,
        maxEnrollment: Int? = nil,
        currentEnrollment: Int? = nil
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
        self.courseCode = courseCode
        self.semester = semester
        self.credits = credits
        self.syllabus = syllabus
        self.schedule = schedule
        self.academicYear = academicYear
        self.courseLevel = courseLevel
        self.prerequisites = prerequisites
        self.maxEnrollment = maxEnrollment
        self.currentEnrollment = currentEnrollment
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
            if role.permissions.contains(permission.permissionString) {
                return true
            }
        }
        
        return false
    }

    /// 檢查成員是否為組織擁有者 (Owner)
    func isOwner(in organization: Organization) -> Bool {
        return hasPermission(OrgPermission.deleteOrganization, in: organization)
    }

    /// 檢查成員是否為組織管理員 (Admin)
    func isAdmin(in organization: Organization) -> Bool {
        // 管理員通常能管理成員和角色
        let hasAdminPermissions = hasPermission(OrgPermission.manageMembers, in: organization) &&
                                  hasPermission(OrgPermission.changeRoles, in: organization)
        return hasAdminPermissions
    }
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

// MARK: - Invitation

struct Invitation: Codable, Identifiable {
    @DocumentID var id: String?
    var organizationId: String
    var inviterId: String
    var code: String
    var roleIds: [String] // 賦予的預設角色
    
    var expirationDate: Date? // 如果為 nil 則永不過期
    var maxUses: Int?         // 最大使用次數，nil 為無限
    var currentUses: Int      // 目前已使用次數
    
    var createdAt: Date
    var updatedAt: Date
    
    var isActive: Bool {
        if let expiration = expirationDate, expiration < Date() {
            return false
        }
        if let max = maxUses, currentUses >= max {
            return false
        }
        return true
    }
    
    init(
        id: String? = nil,
        organizationId: String,
        inviterId: String,
        code: String = String(UUID().uuidString.prefix(8)).uppercased(),
        roleIds: [String],
        expirationDate: Date? = nil,
        maxUses: Int? = nil,
        currentUses: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.inviterId = inviterId
        self.code = code
        self.roleIds = roleIds
        self.expirationDate = expirationDate
        self.maxUses = maxUses
        self.currentUses = currentUses
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
