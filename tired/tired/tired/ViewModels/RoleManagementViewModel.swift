import Foundation
import Combine
import FirebaseAuth // For userId
import FirebaseFirestore // Required for FirebaseManager.shared.db access

@MainActor
class RoleManagementViewModel: ObservableObject {
    @Published var organization: Organization
    @Published var isLoading = false
    
    private let organizationService = OrganizationService()
    private let permissionService = PermissionService() // Inject PermissionService
    private var userId: String? { // Current authenticated user ID
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(organization: Organization) {
        self.organization = organization
    }
    
    var roles: [Role] {
        organization.roles.sorted { (r1, r2) -> Bool in
            if r1.isDefault == true && r2.isDefault != true { return true }
            if r1.isDefault != true && r2.isDefault == true { return false }
            return r1.name < r2.name
        }
    }

    func addRole(name: String, permissions: [String]) async {
        guard let orgId = organization.id, let currentUserId = userId else {
            ToastManager.shared.showToast(message: "操作失敗：用戶未登入或組織ID無效。", type: .error)
            return
        }
        guard !name.isEmpty else {
            ToastManager.shared.showToast(message: "角色名稱不能為空。", type: .error)
            return
        }
        
        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限新增組織角色。", type: .error)
                return
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return
        }
        
        isLoading = true
        do {
            _ = try await organizationService.addRole(name: name, permissions: permissions, toOrganizationId: orgId)
            await refreshOrganization()
            ToastManager.shared.showToast(message: "角色新增成功！", type: .success)
        } catch {
            ToastManager.shared.showToast(message: "新增角色失敗: \(error.localizedDescription)", type: .error)
        }
        isLoading = false
    }

    func updateRole(_ role: Role) async {
        guard let orgId = organization.id, let currentUserId = userId else {
            ToastManager.shared.showToast(message: "操作失敗：用戶未登入或組織ID無效。", type: .error)
            return
        }
        guard !canEditOrDelete(role: role) else { // Use helper for checks
            ToastManager.shared.showToast(message: "您沒有權限編輯此角色或此角色為預設角色。", type: .error)
            return
        }

        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限編輯組織角色。", type: .error)
                return
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return
        }

        isLoading = true
        do {
            try await organizationService.updateRole(role, inOrganizationId: orgId)
            await refreshOrganization()
            ToastManager.shared.showToast(message: "角色更新成功！", type: .success)
        } catch {
            ToastManager.shared.showToast(message: "更新角色失敗: \(error.localizedDescription)", type: .error)
        }
        isLoading = false
    }

    func deleteRole(_ role: Role) async {
        guard let orgId = organization.id, let currentUserId = userId else {
            ToastManager.shared.showToast(message: "操作失敗：用戶未登入或組織ID無效。", type: .error)
            return
        }
        guard !canEditOrDelete(role: role) else { // Use helper for checks
            ToastManager.shared.showToast(message: "您沒有權限刪除此角色或此角色為預設角色。", type: .error)
            return
        }

        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限刪除組織角色。", type: .error)
                return
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return
        }
        
        isLoading = true
        do {
            try await organizationService.deleteRole(role, fromOrganizationId: orgId)
            await refreshOrganization()
            ToastManager.shared.showToast(message: "角色刪除成功！", type: .success)
        } catch {
            ToastManager.shared.showToast(message: "刪除角色失敗: \(error.localizedDescription)", type: .error)
        }
        isLoading = false
    }
    
    private func refreshOrganization() async {
        guard let orgId = organization.id else { return }
        do {
            self.organization = try await organizationService.fetchOrganization(id: orgId) ?? self.organization
        } catch {
            ToastManager.shared.showToast(message: "刷新組織資料失敗: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// 判斷當前用戶是否可以管理角色 (e.g., 創建新角色)
    func canManageRoles() async -> Bool {
        guard let orgId = organization.id, let currentUserId = userId else { return false }
        do {
            return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
        } catch {
            print("Error checking manage roles permission: \(error)")
            return false
        }
    }
    
    /// 判斷當前用戶是否可以編輯或刪除特定角色 (考慮預設角色)
    func canEditOrDelete(role: Role) -> Bool {
        guard let orgId = organization.id, let currentUserId = userId else { return false }
        
        // Default roles cannot be edited or deleted
        guard role.isDefault != true else { return false }

        // Check if user has manageOrgRoles permission (async check)
        return Task {
            return await canManageRoles()
        }.value ?? false // Use value property to get the result of the Task
    }
}
