import Foundation
import Combine
import FirebaseAuth

/// 組織視圖的ViewModel
class OrganizationsViewModel: ObservableObject {
    @Published var myMemberships: [MembershipWithOrg] = []
    @Published var allOrganizations: [Organization] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let organizationService = OrganizationService()
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

        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // 創建組織
        let orgId = try await organizationService.createOrganization(org)

        // 自動為創建者添加owner身份
        let membership = Membership(
            userId: userId,
            organizationId: orgId,
            role: .owner
        )

        try await organizationService.createMembership(membership)

        return orgId
    }

    /// 加入組織
    func joinOrganization(organizationId: String, role: MembershipRole = .member) async throws {
        guard let userId = userId else {
            throw NSError(domain: "OrganizationsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let membership = Membership(
            userId: userId,
            organizationId: organizationId,
            role: role
        )

        try await organizationService.createMembership(membership)
    }

    /// 離開組織
    func leaveOrganization(membershipId: String) async throws {
        try await organizationService.deleteMembership(id: membershipId)
    }

    /// 搜索組織（簡化版）
    func searchOrganizations(query: String) {
        // TODO: 實現搜索功能
        // 這裡可以添加 Firestore 查詢來搜索組織
    }
}
