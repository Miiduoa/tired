import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 組織視圖的ViewModel
class OrganizationsViewModel: ObservableObject {
    @Published var myMemberships: [MembershipWithOrg] = []
    @Published var allOrganizations: [Organization] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let organizationService = OrganizationService()
    private let algoliaService: AlgoliaService? = AlgoliaService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let userId = userId else { return }

        // 訂閱用戶的組織
        organizationService.fetchUserOrganizations(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching user organizations: \(error)")
                    }
                },
                receiveValue: { [weak self] memberships in
                    self?.myMemberships = memberships
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 創建新組織
    func createOrganization(name: String, type: OrgType, description: String?) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "OrganizationsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let org = Organization(
            name: name,
            type: type,
            description: description,
            isVerified: false,
            createdByUserId: userId
        )

        await MainActor.run { isLoading = true }
        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }

        // The service now handles creating default roles and owner membership internally
        do {
            let orgId = try await organizationService.createOrganization(org)
            ToastManager.shared.showToast(message: "組織創建成功！", type: .success)
            return orgId
        } catch {
            ToastManager.shared.showToast(message: "組織創建失敗：\(error.localizedDescription)", type: .error)
            throw error // Re-throw the error as the function is async throws
        }
    }

    /// 申請加入組織
    func requestToJoinOrganization(organizationId: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "OrganizationsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        let userName = Auth.auth().currentUser?.displayName ?? "匿名用戶"

        try await organizationService.createMembershipRequest(
            organizationId: organizationId,
            userId: userId,
            userName: userName,
            type: .request
        )
        ToastManager.shared.showToast(message: "加入組織申請已送出！", type: .success)
    }

    /// 離開組織
    func leaveOrganization(membershipId: String) async throws {
        try await organizationService.deleteMembership(id: membershipId)
    }

    /// 搜索組織 (使用 Algolia)
    func searchOrganizations(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run { allOrganizations = [] }
            return
        }

        guard let algoliaService = algoliaService else {
            await MainActor.run {
                self.errorMessage = "搜尋服務未設定"
                ToastManager.shared.showToast(message: "搜尋服務未設定", type: .error)
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }

        do {
            // 1. 使用 Algolia 取得組織 ID
            let orgIDs = try await algoliaService.search(query: query)

            if orgIDs.isEmpty {
                await MainActor.run { self.allOrganizations = [] }
                return
            }

            // 2. 使用 OrganizationService 的快取機制批次獲取組織完整資料
            let orgsDict = try await organizationService.fetchOrganizations(ids: orgIDs)
            
            // 維持 Algolia 回傳的排序
            let sortedOrgs = orgIDs.compactMap { orgsDict[$0] }

            await MainActor.run {
                self.allOrganizations = sortedOrgs
            }
        } catch {
            print("❌ Error searching organizations with Algolia: \(error)")
            await MainActor.run {
                self.errorMessage = "搜尋失敗：\(error.localizedDescription)"
                ToastManager.shared.showToast(message: "搜尋失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
}
