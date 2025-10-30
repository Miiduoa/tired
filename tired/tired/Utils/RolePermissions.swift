import Foundation

enum RolePermissions {
    static func canManage(_ role: TenantMembership.Role) -> Bool {
        role.isManagerial
    }

    static func canPublish(_ role: TenantMembership.Role) -> Bool {
        // members can publish to feed; managerial can publish broadcasts, etc.
        role == .member || role.isManagerial
    }

    static func canManageMembers(_ role: TenantMembership.Role) -> Bool {
        switch role {
        case .owner, .admin: return true
        default: return false
        }
    }
}

