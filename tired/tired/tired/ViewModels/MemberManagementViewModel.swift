import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
class MemberManagementViewModel: ObservableObject {
    @Published var members: [MemberWithProfile] = []
    @Published var isLoading = false
    
    let organization: Organization
    private let organizationService = OrganizationService()
    private let userService = UserService()
    private let permissionService = PermissionService() // Inject PermissionService
    private var userId: String? { // Current authenticated user ID
        FirebaseAuth.Auth.auth().currentUser?.uid
    }
    
    init(organization: Organization) {
        self.organization = organization
        fetchMembers()
    }
    
    func fetchMembers() {
        guard organization.id != nil else { return }
        
        isLoading = true
        
        _Concurrency.Task {
            await fetchMembersAsync()
        }
    }
    
    private func fetchMembersAsync() async {
        guard let orgId = organization.id else { return }
        
        do {
            let memberships = try await organizationService.fetchOrganizationMembers(organizationId: orgId)
            
            var membersWithProfiles: [MemberWithProfile] = []
            
            for membership in memberships {
                let profile = try? await userService.fetchUserProfile(userId: membership.userId)
                membersWithProfiles.append(MemberWithProfile(membership: membership, userProfile: profile))
            }
            
            await MainActor.run {
                self.members = membersWithProfiles
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                ToastManager.shared.showToast(message: "載入成員失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func updateMemberRoles(membership: Membership, newRoleIds: [String]) async {
        guard let orgId = organization.id, let membershipId = membership.id, let currentUserId = userId else {
            ToastManager.shared.showToast(message: "操作失敗：組織ID或成員ID不存在。", type: .error)
            return
        }
        
        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgMembers)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限管理組織成員角色。", type: .error)
                return
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return
        }

        // Additional logic: Prevent self-demotion if it would leave the organization without an owner/admin
        // This is complex and might depend on specific business rules. For simplicity, we'll allow it for now,
        // but note this as a potential future enhancement for robustness.
        
        do {
            try await organizationService.changeMemberRoles(membershipId: membershipId, newRoleIds: newRoleIds)
            
            // Refresh members list
            await fetchMembersAsync()
            
            await MainActor.run {
                ToastManager.shared.showToast(message: "角色已更新！", type: .success)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast(message: "更新角色失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func removeMember(membership: Membership) async {
        guard let orgId = organization.id, let membershipId = membership.id, let currentUserId = userId else {
            ToastManager.shared.showToast(message: "操作失敗：組織ID或成員ID不存在。", type: .error)
            return
        }
        
        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgMembers)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限移除組織成員。", type: .error)
                return
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return
        }
        
        // Prevent removing self if you're the last admin/owner (complex, future enhancement)
        if membership.userId == currentUserId {
            // Further checks needed to ensure org isn't left without manager.
            // For now, allow self-removal.
            ToastManager.shared.showToast(message: "您已移除自己。", type: .info)
        }
        
        do {
            try await organizationService.deleteMembership(id: membershipId)
            await fetchMembersAsync() // Refresh list
            ToastManager.shared.showToast(message: "成員已移除！", type: .success)
        } catch {
            ToastManager.shared.showToast(message: "移除成員失敗：\(error.localizedDescription)", type: .error)
        }
    }
    
    /// 判斷當前用戶是否可以管理成員 (例如更改角色或移除)
    func canManageMembers() async -> Bool {
        guard let orgId = organization.id else { return false }
        do {
            return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgMembers)
        } catch {
            print("Error checking manage members permission: \(error)")
            return false
        }
    }
}

