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
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
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

    /// 搜索組織
    func searchOrganizations(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                allOrganizations = []
            }
            return
        }

        await MainActor.run {
            isLoading = true
        }

        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }

        do {
            // Firestore 不支持全文搜索，我們使用前綴匹配
            // 搜索名稱以查詢開頭的組織（區分大小寫）
            let queryLower = query.lowercased()

            // 獲取所有組織然後在客戶端過濾
            // 注意：在生產環境中應該使用 Algolia 或 Elasticsearch 等全文搜索服務
            let snapshot = try await FirebaseManager.shared.db
                .collection("organizations")
                .limit(to: 50)
                .getDocuments()

            let organizations = snapshot.documents.compactMap { doc -> Organization? in
                try? doc.data(as: Organization.self)
            }.filter { org in
                org.name.lowercased().contains(queryLower)
            }

            await MainActor.run {
                self.allOrganizations = organizations
            }
        } catch {
            print("❌ Error searching organizations: \(error)")
            await MainActor.run {
                self.errorMessage = "搜索失敗：\(error.localizedDescription)"
            }
        }
    }
}
