import Foundation

// MARK: - Enums

enum OrgType: String, Codable, CaseIterable {
    case school
    case department
    case club
    case company
    case project
    case other

    var displayName: String {
        switch self {
        case .school: return "学校"
        case .department: return "系所"
        case .club: return "社团"
        case .company: return "公司"
        case .project: return "专案"
        case .other: return "其他"
        }
    }
}

// MARK: - Organization Permission

/// 組織權限類型
enum OrgPermission: CaseIterable {
    // Owner 專屬權限
    case deleteOrganization     // 刪除組織
    case transferOwnership      // 轉移所有權

    // Admin 及以上權限
    case manageMembers         // 管理成員
    case changeRoles           // 變更角色
    case removeMembers         // 移除成員
    case manageApps           // 管理小應用
    case editOrgInfo          // 編輯組織資訊

    // Staff 及以上權限
    case createPosts          // 發布貼文
    case createEvents         // 創建活動
    case createTasks          // 創建任務
    case editOwnPosts         // 編輯自己的貼文

    // 所有成員權限
    case viewContent          // 查看內容
    case comment              // 評論
    case joinEvents           // 參加活動
    case react                // 按讚互動
    
    /// 將權限轉換為字符串（用於與 Role.permissions 比較）
    var permissionString: String {
        switch self {
        case .deleteOrganization:
            return AppPermissions.deleteOrganization
        case .transferOwnership:
            return "transfer_ownership" // 特殊權限，通常不存儲在 Role 中
        case .manageMembers:
            return AppPermissions.manageOrgMembers
        case .changeRoles:
            return AppPermissions.manageOrgRoles
        case .removeMembers:
            return AppPermissions.manageOrgMembers // 移除成員是管理成員的一部分
        case .manageApps:
            return AppPermissions.manageOrgApps
        case .editOrgInfo:
            return AppPermissions.editOrgSettings
        case .createPosts:
            return AppPermissions.createPostInOrg
        case .createEvents:
            return AppPermissions.createEventInOrg
        case .createTasks:
            return AppPermissions.createTaskInOrg
        case .editOwnPosts:
            return AppPermissions.deleteOwnPost // 編輯自己的貼文通常等同於刪除自己的貼文權限
        case .viewContent:
            return "view_content" // 所有成員默認擁有
        case .comment:
            return AppPermissions.createTaskCommentInOrg // 評論權限
        case .joinEvents:
            return "join_events" // 所有成員默認擁有
        case .react:
            return "react" // 所有成員默認擁有
        }
    }
    
    /// 權限顯示名稱
    var displayName: String {
        switch self {
        case .deleteOrganization:
            return "刪除組織"
        case .transferOwnership:
            return "轉移所有權"
        case .manageMembers:
            return "管理成員"
        case .changeRoles:
            return "變更角色"
        case .removeMembers:
            return "移除成員"
        case .manageApps:
            return "管理小應用"
        case .editOrgInfo:
            return "編輯組織資訊"
        case .createPosts:
            return "發布貼文"
        case .createEvents:
            return "創建活動"
        case .createTasks:
            return "創建任務"
        case .editOwnPosts:
            return "編輯自己的貼文"
        case .viewContent:
            return "查看內容"
        case .comment:
            return "評論"
        case .joinEvents:
            return "參加活動"
        case .react:
            return "按讚互動"
        }
    }
}

enum MembershipRole: String, Codable, CaseIterable {
    case owner
    case admin
    case staff
    case student
    case member

    var displayName: String {
        switch self {
        case .owner: return "拥有者"
        case .admin: return "管理员"
        case .staff: return "员工"
        case .student: return "学生"
        case .member: return "成员"
        }
    }

    /// 角色層級（數字越大權限越高）
    var hierarchyLevel: Int {
        switch self {
        case .owner: return 5    // 最高管理者/董事長
        case .admin: return 4    // 管理員/經理
        case .staff: return 3    // 員工
        case .student: return 2  // 學生（適用於學校類組織）
        case .member: return 1   // 一般成員
        }
    }

    /// 角色描述
    var description: String {
        switch self {
        case .owner: return "最高管理者，擁有所有權限"
        case .admin: return "管理員，可管理成員和組織內容"
        case .staff: return "員工，可創建內容和參與活動"
        case .student: return "學生，可參與學校活動"
        case .member: return "一般成員，可查看和參與"
        }
    }

    /// 檢查是否可以管理指定角色的成員
    func canManage(_ targetRole: MembershipRole) -> Bool {
        return self.hierarchyLevel > targetRole.hierarchyLevel
    }

    /// 檢查是否有指定權限
    func hasPermission(_ permission: OrgPermission) -> Bool {
        switch permission {
        // Owner 專屬權限
        case .deleteOrganization, .transferOwnership:
            return self == .owner

        // Admin 及以上權限
        case .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo:
            return self.hierarchyLevel >= MembershipRole.admin.hierarchyLevel

        // Staff 及以上權限
        case .createPosts, .createEvents, .createTasks, .editOwnPosts:
            return self.hierarchyLevel >= MembershipRole.staff.hierarchyLevel

        // 所有成員都有的權限
        case .viewContent, .comment, .joinEvents, .react:
            return true
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case school
    case work
    case club
    case personal

    var displayName: String {
        switch self {
        case .school: return "学校"
        case .work: return "工作"
        case .club: return "社团"
        case .personal: return "生活"
        }
    }

    var color: String {
        switch self {
        case .school: return "#3B82F6"    // blue
        case .work: return "#EF4444"      // red
        case .club: return "#8B5CF6"      // purple
        case .personal: return "#10B981"  // green
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    /// 优先级层级（用于排序）✅ 新增
    var hierarchyValue: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

enum TaskSourceType: String, Codable {
    case manual
    case orgTask = "org_task"
    case eventSignup = "event_signup"
}

enum OrgAppTemplateKey: String, Codable {
    case taskBoard = "task_board"
    case eventSignup = "event_signup"
    case resourceList = "resource_list"

    var displayName: String {
        switch self {
        case .taskBoard: return "任务看板"
        case .eventSignup: return "活动报名"
        case .resourceList: return "资源列表"
        }
    }
}

enum PostVisibility: String, Codable {
    case `public`
    case orgMembers = "org_members"
}

enum EventRegistrationStatus: String, Codable {
    case registered
    case cancelled
    case attended
    case noShow = "no_show"
}
