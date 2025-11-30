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
        guard let orgId = organization.id, let _ = userId else {
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
        guard let orgId = organization.id, let _ = userId else {
            ToastManager.shared.showToast(message: "操作失敗：用戶未登入或組織ID無效。", type: .error)
            return
        }
        guard await ensureCanModify(role: role, action: "編輯") else { return }

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
        guard let orgId = organization.id, let _ = userId else {
            ToastManager.shared.showToast(message: "操作失敗：用戶未登入或組織ID無效。", type: .error)
            return
        }
        guard await ensureCanModify(role: role, action: "刪除") else { return }
        
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
            self.organization = try await organizationService.fetchOrganization(id: orgId)
        } catch {
            ToastManager.shared.showToast(message: "刷新組織資料失敗: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// 判斷當前用戶是否可以管理角色 (e.g., 創建新角色)
    func canManageRoles() async -> Bool {
        guard let orgId = organization.id, let _ = userId else { return false }
        do {
            return try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
        } catch {
            print("Error checking manage roles permission: \(error)")
            return false
        }
    }
    
    /// 判斷當前用戶是否可以編輯或刪除特定角色 (考慮預設角色)
    func canEditOrDelete(role: Role) -> Bool {
        // 僅用於同步 UI 判斷：預設角色禁止編輯/刪除
        return role.isDefault != true
    }
    
    /// 異步檢查是否可以編輯或刪除特定角色
    func canEditOrDeleteAsync(role: Role) async -> Bool {
        guard let _ = organization.id, let _ = userId else { return false }
        
        // Default roles cannot be edited or deleted
        guard role.isDefault != true else { return false }

        // Check if user has manageOrgRoles permission
        return await canManageRoles()
    }
    
    /// 確認當前使用者是否可以對指定角色進行變更（含權限與預設角色判斷）
    private func ensureCanModify(role: Role, action: String) async -> Bool {
        guard role.isDefault != true else {
            ToastManager.shared.showToast(message: "預設角色不可\(action)。", type: .error)
            return false
        }
        
        guard let orgId = organization.id else {
            ToastManager.shared.showToast(message: "組織ID無效，無法\(action)角色。", type: .error)
            return false
        }
        
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: orgId, permission: AppPermissions.manageOrgRoles)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限\(action)組織角色。", type: .error)
                return false
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            return false
        }
        
        return true
    }
}
