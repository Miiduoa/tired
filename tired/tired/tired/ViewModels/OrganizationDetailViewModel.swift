import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Organization Detail ViewModel

class OrganizationDetailViewModel: ObservableObject {
    @Published var organization: Organization?
    @Published var posts: [Post] = []
    @Published var apps: [OrgAppInstance] = [] // Only enabled apps
    @Published var allApps: [OrgAppInstance] = [] // All apps for management
    @Published var currentMembership: Membership?
    
    @Published var isMember = false
    @Published var isRequestPending = false
    @Published var requestStatusMessage: String?
    @Published var isLoading = true
    
    // Statistics
    @Published var memberCount = 0
    @Published var taskCount = 0
    @Published var eventCount = 0
    @Published var isLoadingStats = false
    
    let organizationId: String
    private let postService = PostService()
    private let organizationService = OrganizationService()
    private let db = FirebaseManager.shared.db
    private var cancellables = Set<AnyCancellable>()
    
    // Realtime listeners
    private var organizationListener: ListenerRegistration?
    private var rolesListener: ListenerRegistration?
    private var membershipListener: ListenerRegistration?
    private var requestListener: ListenerRegistration?
    private var appsListener: ListenerRegistration?

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(organizationId: String) {
        self.organizationId = organizationId
        _Concurrency.Task {
            await fetchOrganization()
            setupSubscriptions()
            startRealtimeListeners()
            checkMembership()
            checkRequestStatus()
            fetchStatistics()
        }
    }
    
    deinit {
        organizationListener?.remove()
        rolesListener?.remove()
        membershipListener?.remove()
        requestListener?.remove()
        appsListener?.remove()
    }

    func fetchOrganization() async {
        await MainActor.run { isLoading = true }
        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }
        
        do {
            let org = try await organizationService.fetchOrganization(id: organizationId)
            await MainActor.run {
                self.organization = org
            }
        } catch {
            print("❌ Failed to fetch organization with id \(organizationId): \(error)")
        }
    }

    private func setupSubscriptions() {
        // 訂閱組織貼文
        postService.fetchOrganizationPosts(organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] posts in
                    self?.posts = posts
                }
            )
            .store(in: &cancellables)

        // 獲取小應用
        _Concurrency.Task {
            await fetchApps()
            await fetchAllApps()
        }
    }
    
    // MARK: - Realtime listeners
    
    private func startRealtimeListeners() {
        startOrganizationListener()
        startRolesListener()
        startMembershipListener()
        startRequestListener()
        startAppsListener()
    }

    private func startOrganizationListener() {
        organizationListener?.remove()
        organizationListener = db.collection("organizations")
            .document(organizationId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let org = try? snapshot?.data(as: Organization.self) else { return }
                
                var updatedOrg = org
                updatedOrg.id = self.organizationId
                // Keep roles in sync via rolesListener to avoid losing cached values
                updatedOrg.roles = self.organization?.roles ?? []
                
                DispatchQueue.main.async {
                    self.organization = updatedOrg
                }
            }
    }
    
    private func startRolesListener() {
        rolesListener?.remove()
        rolesListener = db.collection("organizations")
            .document(organizationId)
            .collection("roles")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                let roles: [Role] = documents.compactMap { doc in
                    var role = try? doc.data(as: Role.self)
                    role?.id = doc.documentID
                    return role
                }
                
                DispatchQueue.main.async {
                    if var org = self.organization {
                        org.roles = roles
                        self.organization = org
                    }
                }
            }
    }
    
    private func startMembershipListener() {
        guard let userId = userId else { return }
        
        membershipListener?.remove()
        membershipListener = db.collection("memberships")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                guard let doc = snapshot?.documents.first,
                      let membership = try? doc.data(as: Membership.self) else {
                    DispatchQueue.main.async {
                        self.currentMembership = nil
                        self.isMember = false
                        self.isRequestPending = false
                        self.requestStatusMessage = nil
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentMembership = membership
                    self.isMember = true
                    self.isRequestPending = false
                    self.requestStatusMessage = nil
                }
                
                // Refresh statistics when membership status changes
                self.fetchStatistics()
            }
    }
    
    private func startRequestListener() {
        guard let userId = userId else { return }
        
        requestListener?.remove()
        requestListener = db.collection("membershipRequests")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: MembershipRequest.RequestStatus.pending.rawValue)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                let hasPending = (snapshot?.documents.isEmpty == false)
                
                DispatchQueue.main.async {
                    self.isRequestPending = hasPending
                    self.requestStatusMessage = hasPending ? "申請已送出，等待管理員審核" : nil
                }
            }
    }
    
    private func startAppsListener() {
        appsListener?.remove()
        appsListener = db.collection("orgAppInstances")
            .whereField("organizationId", isEqualTo: organizationId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                let instances = documents.compactMap { doc -> OrgAppInstance? in
                    try? doc.data(as: OrgAppInstance.self)
                }
                
                DispatchQueue.main.async {
                    self.allApps = instances
                    self.apps = instances.filter { $0.isEnabled }
                }
            }
    }

    private func fetchApps() async {
        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("orgAppInstances")
                .whereField("organizationId", isEqualTo: organizationId)
                .whereField("isEnabled", isEqualTo: true)
                .getDocuments()

            let apps = snapshot.documents.compactMap { doc -> OrgAppInstance? in
                try? doc.data(as: OrgAppInstance.self)
            }

            await MainActor.run { self.apps = apps }
        } catch {
            print("❌ Error fetching enabled apps: \(error)")
        }
    }
    
    private func fetchAllApps() async {
        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("orgAppInstances")
                .whereField("organizationId", isEqualTo: organizationId)
                .getDocuments()

            let apps = snapshot.documents.compactMap { doc -> OrgAppInstance? in
                try? doc.data(as: OrgAppInstance.self)
            }

            await MainActor.run { self.allApps = apps }
        } catch {
            print("❌ Error fetching all apps: \(error)")
        }
    }

    private func checkMembership() {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: organizationId)
                    .getDocuments()

                let membership = snapshot.documents.first.flatMap { try? $0.data(as: Membership.self) }
                
                await MainActor.run {
                    self.currentMembership = membership
                    self.isMember = membership != nil
                }
            } catch {
                print("❌ Error checking membership: \(error)")
            }
        }
    }

    private func checkRequestStatus() {
        guard let userId = userId, !isMember else { return }

        _Concurrency.Task {
            do {
                let snapshot = try await FirebaseManager.shared.db.collection("membershipRequests")
                    .whereField("organizationId", isEqualTo: organizationId)
                    .whereField("userId", isEqualTo: userId)
                    .whereField("status", isEqualTo: "pending")
                    .limit(to: 1)
                    .getDocuments()

                await MainActor.run {
                    if !snapshot.documents.isEmpty {
                        self.isRequestPending = true
                        self.requestStatusMessage = "申請已送出，等待管理員審核"
                    }
                }
            } catch {
                print("❌ Error checking membership request status: \(error)")
            }
        }
    }
    
    func requestToJoinOrganization() {
        guard let userId = userId, !isRequestPending else { return }
        let userName = Auth.auth().currentUser?.displayName ?? "匿名用戶"

        _Concurrency.Task {
            do {
                try await organizationService.createMembershipRequest(
                    organizationId: organizationId,
                    userId: userId,
                    userName: userName,
                    type: .request
                )
                await MainActor.run {
                    self.isRequestPending = true
                    self.requestStatusMessage = "申請已送出，等待管理員審核"
                }
            } catch {
                print("❌ Error requesting to join organization: \(error)")
                await MainActor.run { self.requestStatusMessage = "申請失敗，請稍後再試" }
            }
        }
    }

    /// 非同步版本，回傳成功/失敗，供 UI 使用
    func requestToJoinOrganizationAsync() async -> Bool {
        guard let userId = userId, !isRequestPending else { return false }
        let userName = Auth.auth().currentUser?.displayName ?? "匿名用戶"

        do {
            try await organizationService.createMembershipRequest(
                organizationId: organizationId,
                userId: userId,
                userName: userName,
                type: .request
            )
            await MainActor.run {
                self.isRequestPending = true
                self.requestStatusMessage = "申請已送出，等待管理員審核"
                AlertHelper.shared.showSuccess("申請已送出")
            }
            return true
        } catch {
            print("❌ Error requesting to join organization async: \(error)")
            await MainActor.run {
                self.requestStatusMessage = "申請失敗，請稍後再試"
                AlertHelper.shared.showError("申請失敗：\(error.localizedDescription)")
            }
            return false
        }
    }

    func leaveOrganization() {
        guard let membership = currentMembership else { return }

        _Concurrency.Task {
            do {
                // 使用 handleMemberLeave 來處理所有權轉移邏輯
                try await organizationService.handleMemberLeave(membership: membership)
                await MainActor.run {
                    self.isMember = false
                    self.currentMembership = nil
                    self.isRequestPending = false
                    self.requestStatusMessage = nil
                }
            } catch {
                print("❌ Error leaving organization: \(error)")
            }
        }
    }

    /// 非同步版本，回傳是否離開成功，供 UI 使用
    func leaveOrganizationAsync() async -> Bool {
        guard let membership = currentMembership else { return false }

        do {
            // 使用 handleMemberLeave 來處理所有權轉移邏輯
            try await organizationService.handleMemberLeave(membership: membership)
            await MainActor.run {
                self.isMember = false
                self.currentMembership = nil
                self.isRequestPending = false
                self.requestStatusMessage = nil
                AlertHelper.shared.showSuccess("已退出組織")
            }
            return true
        } catch {
            print("❌ Error leaving organization async: \(error)")
            await MainActor.run { AlertHelper.shared.showError("退出組織失敗：\(error.localizedDescription)") }
            return false
        }
    }
    
    // MARK: - App Management
    // Async versions that return success/failure for UI callers
    func enableAppAsync(templateKey: OrgAppTemplateKey) async -> Bool {
        guard let orgId = organization?.id else { return false }

        do {
            // 若已有相同模板的應用，優先復用並啟用，而不是重複新增
            if let existing = allApps.first(where: { $0.templateKey == templateKey }) {
                if let existingId = existing.id {
                    try await FirebaseManager.shared.db.collection("orgAppInstances").document(existingId).updateData([
                        "isEnabled": true,
                        "updatedAt": Date()
                    ])
                } else {
                    var instance = existing
                    instance.isEnabled = true
                    instance.updatedAt = Date()
                    let _ = try FirebaseManager.shared.db.collection("orgAppInstances").addDocument(from: instance)
                }
            } else {
                let instance = OrgAppInstance(organizationId: orgId, templateKey: templateKey, isEnabled: true)
                let _ = try FirebaseManager.shared.db.collection("orgAppInstances").addDocument(from: instance)
            }
            // Refresh local lists
            await fetchApps()
            await fetchAllApps()
            await MainActor.run { AlertHelper.shared.showSuccess("應用已啟用") }
            return true
        } catch {
            print("❌ Error enabling app async: \(error)")
            await MainActor.run { AlertHelper.shared.showError("啟用應用失敗：\(error.localizedDescription)") }
            return false
        }
    }

    func disableAppAsync(appInstance: OrgAppInstance) async -> Bool {
        guard let id = appInstance.id else { return false }

        do {
            // Prefer to update isEnabled flag to false to keep history
            try await FirebaseManager.shared.db.collection("orgAppInstances").document(id).updateData([
                "isEnabled": false,
                "updatedAt": Date()
            ])
            await fetchApps()
            await fetchAllApps()
            await MainActor.run { AlertHelper.shared.showSuccess("應用已停用") }
            return true
        } catch {
            print("❌ Error disabling app async: \(error)")
            await MainActor.run { AlertHelper.shared.showError("停用應用失敗：\(error.localizedDescription)") }
            return false
        }
    }

    // Backwards-compatible fire-and-forget wrappers
    func enableApp(templateKey: OrgAppTemplateKey) {
        _Concurrency.Task { _ = await enableAppAsync(templateKey: templateKey) }
    }

    func disableApp(appInstance: OrgAppInstance) {
        _Concurrency.Task { _ = await disableAppAsync(appInstance: appInstance) }
    }

    // MARK: - Permissions
    var canManageMembers: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.manageMembers, in: org)
    }

    var canCreatePosts: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.createPosts, in: org)
    }
    
    var canCreateAnnouncements: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.createAnnouncement, in: org)
    }
    
    var canCreateEvents: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.createEvents, in: org)
    }
    
    var canCreateTasks: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.createTasks, in: org)
    }

    var canManageApps: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.manageApps, in: org)
    }

    var canChangeRoles: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.changeRoles, in: org)
    }
    
    var canEditOrgInfo: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.editOrgInfo, in: org)
    }
    
    var canDeleteOrganization: Bool {
        guard let membership = currentMembership, let org = organization, let userId = userId else { return false }
        return membership.hasPermission(.deleteOrganization, in: org) && org.createdByUserId == userId
    }
    
    // MARK: - Invitations & sharing
    
    /// 取得一組可分享的邀請碼（若已有有效邀請會直接重用）
    func prepareShareableInvitation() async throws -> Invitation {
        guard let orgId = organization?.id else {
            throw NSError(domain: "OrganizationDetailViewModel", code: -20, userInfo: [NSLocalizedDescriptionKey: "找不到組織資訊"])
        }
        guard let inviterId = userId else {
            throw NSError(domain: "OrganizationDetailViewModel", code: -21, userInfo: [NSLocalizedDescriptionKey: "尚未登入，無法建立邀請碼"])
        }
        
        var orgSnapshot = organization
        if orgSnapshot?.roles.isEmpty != false {
            let refreshed = try await organizationService.fetchOrganization(id: orgId)
            orgSnapshot = refreshed
            await MainActor.run { self.organization = refreshed }
        }
        
        guard let defaultRoleId = orgSnapshot?.roles.first(where: { $0.name == "成員" })?.id ?? orgSnapshot?.roles.first?.id else {
            throw NSError(domain: "OrganizationDetailViewModel", code: -22, userInfo: [NSLocalizedDescriptionKey: "找不到可用的角色，請先設定組織角色。"])
        }
        
        // 先嘗試重用有效邀請碼，避免生成過多一次性邀請
        let invitations = try await organizationService.fetchInvitations(organizationId: orgId)
        if let active = invitations.first(where: { $0.isActive && $0.roleIds.contains(defaultRoleId) }) {
            return active
        }
        
        // 預設產生 72 小時、50 次使用的邀請碼
        return try await organizationService.createInvitation(
            organizationId: orgId,
            inviterId: inviterId,
            roleIds: [defaultRoleId],
            maxUses: 50,
            expirationHours: 72
        )
    }
    
    // MARK: - Organization Management
    
    /// 更新組織信息
    func updateOrganizationAsync(name: String, description: String?, type: OrgType) async -> Bool {
        guard var org = organization, org.id != nil else { return false }
        
        // 權限檢查
        guard canEditOrgInfo else {
            await MainActor.run {
                AlertHelper.shared.showError("您沒有權限編輯組織信息")
            }
            return false
        }
        
        org.name = name
        org.description = description
        org.type = type
        org.updatedAt = Date()
        
        do {
            try await organizationService.updateOrganization(org)
            await MainActor.run {
                self.organization = org
                AlertHelper.shared.showSuccess("組織信息已更新")
            }
            return true
        } catch {
            print("❌ Error updating organization: \(error)")
            await MainActor.run {
                AlertHelper.shared.showError("更新失敗：\(error.localizedDescription)")
            }
            return false
        }
    }
    
    /// 刪除組織
    func deleteOrganizationAsync() async -> Bool {
        guard let orgId = organization?.id, let userId = userId else { return false }
        
        // 權限檢查
        guard canDeleteOrganization else {
            await MainActor.run {
                AlertHelper.shared.showError("您沒有權限刪除組織")
            }
            return false
        }
        
        do {
            try await organizationService.deleteOrganization(organizationId: orgId, userId: userId)
            await MainActor.run {
                AlertHelper.shared.showSuccess("組織已刪除")
            }
            return true
        } catch {
            print("❌ Error deleting organization: \(error)")
            await MainActor.run {
                AlertHelper.shared.showError("刪除失敗：\(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Statistics
    
    func fetchStatistics() {
        guard let orgId = organization?.id else { return }
        
        isLoadingStats = true
        
        _Concurrency.Task {
            do {
                // 獲取成員數量
                let members = try await organizationService.fetchOrganizationMembers(organizationId: orgId)
                
                // 獲取任務數量
                let tasksSnapshot = try await FirebaseManager.shared.db
                    .collection("tasks")
                    .whereField("sourceOrgId", isEqualTo: orgId)
                    .getDocuments()
                
                // 獲取活動數量
                let eventsSnapshot = try await FirebaseManager.shared.db
                    .collection("events")
                    .whereField("organizationId", isEqualTo: orgId)
                    .getDocuments()
                
                await MainActor.run {
                    self.memberCount = members.count
                    self.taskCount = tasksSnapshot.documents.count
                    self.eventCount = eventsSnapshot.documents.count
                    self.isLoadingStats = false
                }
            } catch {
                print("❌ Error fetching organization statistics: \(error)")
                await MainActor.run {
                    self.isLoadingStats = false
                }
            }
        }
    }
}
