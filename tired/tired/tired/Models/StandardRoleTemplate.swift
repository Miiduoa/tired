import Foundation

/// 標準角色模板
/// 根據組織類型提供預設的角色和權限配置
enum StandardRoleTemplate {
    case school       // 學校
    case department   // 系所
    case course       // 課程
    case company      // 公司
    case club         // 社團
    case project      // 專案
    case other        // 其他

    /// 從 OrgType 轉換
    static func from(_ orgType: OrgType) -> StandardRoleTemplate {
        switch orgType {
        case .school: return .school
        case .department: return .department
        case .course: return .course
        case .company: return .company
        case .club: return .club
        case .project: return .project
        case .other: return .other
        }
    }

    /// 獲取該組織類型的標準角色配置
    var roles: [(name: String, permissions: [OrgPermission], isDefault: Bool)] {
        switch self {
        case .school:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("校長", schoolPrincipalPermissions, false),
                ("行政人員", schoolStaffPermissions, false),
                ("學生", schoolStudentPermissions, false)
            ]

        case .department:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("系主任", departmentHeadPermissions, false),
                ("教授", departmentProfessorPermissions, false),
                ("助教", departmentTAPermissions, false),
                ("學生", departmentStudentPermissions, false)
            ]

        case .course:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("授課教師", courseInstructorPermissions, false),
                ("助教", courseTAPermissions, false),
                ("學生", courseStudentPermissions, false)
            ]

        case .company:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("管理員", companyAdminPermissions, false),
                ("員工", companyStaffPermissions, false),
                ("成員", companyMemberPermissions, false)
            ]

        case .club:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("社長", clubPresidentPermissions, false),
                ("幹部", clubOfficerPermissions, false),
                ("社員", clubMemberPermissions, false)
            ]

        case .project:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("專案經理", projectManagerPermissions, false),
                ("成員", projectMemberPermissions, false)
            ]

        case .other:
            return [
                ("擁有者", OrgPermission.allCases, true),
                ("管理員", genericAdminPermissions, false),
                ("成員", genericMemberPermissions, false)
            ]
        }
    }

    // MARK: - School Permissions

    private var schoolPrincipalPermissions: [OrgPermission] {
        [
            .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo,
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react,
            .manageChildOrgs, .viewChildOrgs, .createChildOrgs
        ]
    }

    private var schoolStaffPermissions: [OrgPermission] {
        [
            .viewContent, .editOrgInfo, .createPosts, .createAnnouncement,
            .createEvents, .createTasks, .comment, .joinEvents, .react,
            .viewChildOrgs
        ]
    }

    private var schoolStudentPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react, .viewChildOrgs
        ]
    }

    // MARK: - Department Permissions

    private var departmentHeadPermissions: [OrgPermission] {
        [
            .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo,
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react,
            .manageChildOrgs, .viewChildOrgs, .createChildOrgs
        ]
    }

    private var departmentProfessorPermissions: [OrgPermission] {
        [
            .viewContent, .createPosts, .createAnnouncement, .createEvents,
            .comment, .joinEvents, .react,
            .viewChildOrgs, .createChildOrgs
        ]
    }

    private var departmentTAPermissions: [OrgPermission] {
        [
            .viewContent, .createPosts, .comment, .joinEvents, .react,
            .viewChildOrgs
        ]
    }

    private var departmentStudentPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react, .viewChildOrgs
        ]
    }

    // MARK: - Course Permissions

    private var courseInstructorPermissions: [OrgPermission] {
        [
            .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo,
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react,
            .gradeAssignments, .manageGrades, .takeAttendance, .viewAttendance
        ]
    }

    private var courseTAPermissions: [OrgPermission] {
        [
            .viewContent, .createPosts, .createAnnouncement, .comment, .joinEvents, .react,
            .gradeAssignments, .viewGrades, .takeAttendance, .viewAttendance
        ]
    }

    private var courseStudentPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react,
            .submitAssignments, .viewGrades, .viewAttendance
        ]
    }

    // MARK: - Company Permissions

    private var companyAdminPermissions: [OrgPermission] {
        OrgPermission.allCases.filter {
            switch $0 {
            case .deleteOrganization, .transferOwnership: return false
            default: return true
            }
        }
    }

    private var companyStaffPermissions: [OrgPermission] {
        [
            .viewContent, .createPosts, .createEvents, .createTasks,
            .editOwnPosts, .comment, .joinEvents, .react
        ]
    }

    private var companyMemberPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react
        ]
    }

    // MARK: - Club Permissions

    private var clubPresidentPermissions: [OrgPermission] {
        [
            .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo,
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react
        ]
    }

    private var clubOfficerPermissions: [OrgPermission] {
        [
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react
        ]
    }

    private var clubMemberPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react
        ]
    }

    // MARK: - Project Permissions

    private var projectManagerPermissions: [OrgPermission] {
        [
            .manageMembers, .changeRoles, .removeMembers, .manageApps, .editOrgInfo,
            .createPosts, .createAnnouncement, .createEvents, .createTasks,
            .viewContent, .comment, .joinEvents, .react
        ]
    }

    private var projectMemberPermissions: [OrgPermission] {
        [
            .viewContent, .createPosts, .createTasks, .editOwnPosts,
            .comment, .joinEvents, .react
        ]
    }

    // MARK: - Generic Permissions

    private var genericAdminPermissions: [OrgPermission] {
        OrgPermission.allCases.filter {
            switch $0 {
            case .deleteOrganization, .transferOwnership: return false
            default: return true
            }
        }
    }

    private var genericMemberPermissions: [OrgPermission] {
        [
            .viewContent, .comment, .joinEvents, .react
        ]
    }
}
