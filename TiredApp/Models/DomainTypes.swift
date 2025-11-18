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
