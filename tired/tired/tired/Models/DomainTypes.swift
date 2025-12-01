import Foundation

// MARK: - Enums

enum OrgType: String, Codable, CaseIterable {
    case school
    case department
    case course      // 新增：課程類型
    case club
    case company
    case project
    case other

    var displayName: String {
        switch self {
        case .school: return "学校"
        case .department: return "系所"
        case .course: return "课程"
        case .club: return "社团"
        case .company: return "公司"
        case .project: return "专案"
        case .other: return "其他"
        }
    }

    // MARK: - Hierarchy Support (層級結構支援)

    /// 是否支援子組織
    var canHaveChildren: Bool {
        switch self {
        case .school: return true       // 學校可包含系所
        case .department: return true   // 系所可包含課程
        case .course: return false      // 課程不能再包含子組織
        case .club: return false
        case .company: return true      // 公司可包含部門
        case .project: return false
        case .other: return false
        }
    }

    /// 允許的子組織類型
    var allowedChildTypes: [OrgType] {
        switch self {
        case .school: return [.department, .club]
        case .department: return [.course]
        case .company: return [.department, .project]
        default: return []
        }
    }

    /// 預設層級深度（用於建議，實際層級由 parentOrganizationId 決定）
    var defaultLevel: Int {
        switch self {
        case .school: return 0
        case .department: return 1
        case .course: return 2
        case .company: return 0
        case .club: return 1
        case .project: return 1
        case .other: return 0
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
    case createAnnouncement   // 發布公告
    case createEvents         // 創建活動
    case createTasks          // 創建任務
    case editOwnPosts         // 編輯自己的貼文

    // 所有成員權限
    case viewContent          // 查看內容
    case comment              // 評論
    case joinEvents           // 參加活動
    case react                // 按讚互動

    // MARK: - 課程相關權限
    case submitAssignments     // 繳交作業
    case gradeAssignments      // 批改作業
    case viewGrades           // 查看成績
    case manageGrades         // 管理成績
    case takeAttendance       // 點名
    case viewAttendance       // 查看出席紀錄

    // MARK: - 層級管理權限
    case manageChildOrgs      // 管理子組織
    case viewChildOrgs        // 查看子組織
    case createChildOrgs      // 創建子組織
    
    /// 將權限轉換為字符串（用於與 Role.permissions 比較）
    var permissionString: String {
        switch self {
        case .deleteOrganization:
            return AppPermissions.deleteOrganization
        case .transferOwnership:
            return "transfer_ownership"
        case .manageMembers:
            return AppPermissions.manageOrgMembers
        case .changeRoles:
            return AppPermissions.manageOrgRoles
        case .removeMembers:
            return AppPermissions.manageOrgMembers
        case .manageApps:
            return AppPermissions.manageOrgApps
        case .editOrgInfo:
            return AppPermissions.editOrgSettings
        case .createPosts:
            return AppPermissions.createPostInOrg
        case .createAnnouncement:
            return AppPermissions.createAnnouncementInOrg
        case .createEvents:
            return AppPermissions.createEventInOrg
        case .createTasks:
            return AppPermissions.createTaskInOrg
        case .editOwnPosts:
            return AppPermissions.deleteOwnPost
        case .viewContent:
            return "view_content"
        case .comment:
            return AppPermissions.createTaskCommentInOrg
        case .joinEvents:
            return "join_events"
        case .react:
            return "react"
        // 課程相關權限
        case .submitAssignments:
            return "submit_assignments"
        case .gradeAssignments:
            return "grade_assignments"
        case .viewGrades:
            return "view_grades"
        case .manageGrades:
            return "manage_grades"
        case .takeAttendance:
            return "take_attendance"
        case .viewAttendance:
            return "view_attendance"
        // 層級管理權限
        case .manageChildOrgs:
            return "manage_child_orgs"
        case .viewChildOrgs:
            return "view_child_orgs"
        case .createChildOrgs:
            return "create_child_orgs"
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
        case .createAnnouncement:
            return "發布公告"
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
        // 課程相關權限
        case .submitAssignments:
            return "繳交作業"
        case .gradeAssignments:
            return "批改作業"
        case .viewGrades:
            return "查看成績"
        case .manageGrades:
            return "管理成績"
        case .takeAttendance:
            return "點名"
        case .viewAttendance:
            return "查看出席紀錄"
        // 層級管理權限
        case .manageChildOrgs:
            return "管理子組織"
        case .viewChildOrgs:
            return "查看子組織"
        case .createChildOrgs:
            return "創建子組織"
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
        case .createPosts, .createAnnouncement, .createEvents, .createTasks, .editOwnPosts:
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
        case .school: return "學校"
        case .work: return "工作"
        case .club: return "社團"
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

enum OrgAppTemplateKey: String, Codable, CaseIterable {
    case taskBoard = "task_board"
    case eventSignup = "event_signup"
    case resourceList = "resource_list"
    
    // School Specific (TronClass-like)
    case courseSchedule = "course_schedule" // 課表
    case assignmentBoard = "assignment_board" // 作業
    case bulletinBoard = "bulletin_board" // 公告
    case rollCall = "roll_call" // 點名
    case gradebook = "gradebook" // 成績

    var displayName: String {
        switch self {
        case .taskBoard: return "任務看板"
        case .eventSignup: return "活動報名"
        case .resourceList: return "資源列表"
        case .courseSchedule: return "課程表"
        case .assignmentBoard: return "作業專區"
        case .bulletinBoard: return "公告欄"
        case .rollCall: return "點名系統"
        case .gradebook: return "成績查詢"
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
