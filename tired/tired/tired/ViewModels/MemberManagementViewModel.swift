import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
class MemberManagementViewModel: ObservableObject {
    @Published var members: [MemberWithProfile] = []
    @Published var invitations: [Invitation] = []
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
        fetchInvitations()
    }
    
    func fetchMembers() {
        guard organization.id != nil else { return }
        
        isLoading = true
        
        _Concurrency.Task {
            await fetchMembersAsync()
        }
    }
    
    func fetchInvitations() {
        guard let orgId = organization.id else { return }
        
        _Concurrency.Task {
            do {
                let invites = try await organizationService.fetchInvitations(organizationId: orgId)
                await MainActor.run {
                    self.invitations = invites
                }
            } catch {
                print("Error fetching invitations: \(error)")
            }
        }
    }

    func createInvitation(maxUses: Int? = nil, expirationHours: Int? = nil) async {
        guard let orgId = organization.id, let userId = userId else { return }
        
        do {
            // Default role: Member
            // Find member role ID
            // For simplicity, we create invitation with default roles handled by service or we fetch them here.
            // But createInvitation needs roleIds.
            
            // fetch organization roles to find "Member" role
            let org = try await organizationService.fetchOrganization(id: orgId)
            let memberRoleId = org.roles.first(where: { $0.name == "成員" })?.id ?? ""
            
            guard !memberRoleId.isEmpty else {
                await MainActor.run {
                    ToastManager.shared.showToast(message: "無法找到預設成員角色。", type: .error)
                }
                return
            }
            
            _ = try await organizationService.createInvitation(
                organizationId: orgId,
                inviterId: userId,
                roleIds: [memberRoleId],
                maxUses: maxUses,
                expirationHours: expirationHours
            )
            
            fetchInvitations()
            
            await MainActor.run {
                ToastManager.shared.showToast(message: "邀請碼已建立", type: .success)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast(message: "建立邀請失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func deleteInvitation(_ invitation: Invitation) async {
        guard let id = invitation.id else { return }
        do {
            try await organizationService.deleteInvitation(id: id)
            fetchInvitations()
            await MainActor.run {
                ToastManager.shared.showToast(message: "邀請已刪除", type: .success)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast(message: "刪除失敗：\(error.localizedDescription)", type: .error)
            }
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
    
    func updateMemberRoles(membership: Membership, newRoleIds: [String], title: String? = nil) async {
        guard let orgId = organization.id, let membershipId = membership.id, let _ = userId else {
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

        // 防止將最後一位擁有者降級，避免組織成為無主狀態
        if let ownerRoleId = organization.roles.first(where: { $0.name == "擁有者" })?.id {
            let isRemovingOwnerRole = membership.roleIds.contains(ownerRoleId) && !newRoleIds.contains(ownerRoleId)
            if isRemovingOwnerRole {
                do {
                    let members = try await organizationService.fetchOrganizationMembers(organizationId: orgId)
                    let otherOwners = members.filter { $0.id != membership.id && $0.roleIds.contains(ownerRoleId) }
                    guard !otherOwners.isEmpty else {
                        await MainActor.run {
                            ToastManager.shared.showToast(message: "至少需要保留一位擁有者。", type: .error)
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        ToastManager.shared.showToast(message: "檢查擁有者狀態失敗：\(error.localizedDescription)", type: .error)
                    }
                    return
                }
            }
        }
        
        do {
            try await organizationService.changeMemberRoles(membershipId: membershipId, newRoleIds: newRoleIds)
            
            // 如果有更新頭銜，也更新頭銜
            if let title = title {
                var updatedMembership = membership
                updatedMembership.title = title.isEmpty ? nil : title
                updatedMembership.updatedAt = Date()
                try await organizationService.updateMembership(updatedMembership)
            }
            
            // Refresh members list
            await fetchMembersAsync()
            
            await MainActor.run {
                ToastManager.shared.showToast(message: "成員信息已更新！", type: .success)
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast(message: "更新失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func removeMember(membership: Membership) async {
        guard let orgId = organization.id, membership.id != nil, let _ = userId else {
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
        
        // 統一透過 handleMemberLeave 處理，涵蓋擁有者繼任與聊天室移除邏輯
        do {
            try await organizationService.handleMemberLeave(membership: membership)
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
    
    /// 判斷是否可以移除特定成員
    func canRemoveMember(_ member: MemberWithProfile) -> Bool {
        guard let currentUserId = userId else { return false }
        
        // 不能移除自己（應該使用退出功能）
        if member.membership.userId == currentUserId {
            return false
        }
        
        // 檢查當前用戶是否有管理成員的權限
        // 這裡簡化處理，實際應該異步檢查權限
        // 為了 UI 響應性，我們先返回 true，實際權限檢查在 removeMember 中進行
        return true
    }
}
