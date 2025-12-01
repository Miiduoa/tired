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
    // 暫時不需要 AlgoliaService，改用 Firebase 原生查詢
    // private let algoliaService: AlgoliaService? = AlgoliaService()
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

    /// 創建新組織（支援層級結構和課程資訊）
    func createOrganization(
        name: String,
        type: OrgType,
        description: String?,
        parentOrganizationId: String? = nil,
        courseInfo: CourseInfo? = nil
    ) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "OrganizationsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let org = Organization(
            name: name,
            type: type,
            description: description,
            isVerified: false,
            createdByUserId: userId,
            parentOrganizationId: parentOrganizationId,
            courseInfo: courseInfo
        )

        await MainActor.run { isLoading = true }
        // Use explicit main actor updates instead of defer/dispatch to ensure order

        do {
            let orgId = try await organizationService.createOrganization(org)

            await MainActor.run {
                isLoading = false
                let orgTypeName = type.displayName
                ToastManager.shared.showToast(message: "\(orgTypeName)創建成功！", type: .success)
            }
            return orgId
        } catch {
            await MainActor.run {
                isLoading = false
                ToastManager.shared.showToast(message: "組織創建失敗：\(error.localizedDescription)", type: .error)
            }
            throw error
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

    /// 搜索組織 (使用 Firebase 前綴搜尋)
    func searchOrganizations(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { allOrganizations = [] }
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
            // 使用 Firebase 前綴查詢
            let queryEnd = query + "\u{f8ff}"
            let snapshot = try await Firestore.firestore().collection("organizations")
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThan: queryEnd)
                .limit(to: 10)
                .getDocuments()
            
            let orgs = snapshot.documents.compactMap { try? $0.data(as: Organization.self) }

            await MainActor.run {
                self.allOrganizations = orgs
            }
        } catch {
            print("❌ Error searching organizations: \(error)")
            await MainActor.run {
                self.errorMessage = "搜尋失敗：\(error.localizedDescription)"
                ToastManager.shared.showToast(message: "搜尋失敗：\(error.localizedDescription)", type: .error)
            }
        }
    }
    
    /// 透過邀請碼加入組織
    func joinByInvitationCode(code: String) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "OrganizationsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        await MainActor.run { isLoading = true }
        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }
        
        do {
            let orgId = try await organizationService.joinByInvitationCode(code: code, userId: userId)
            
            // 成功後，可能需要重新整理列表 (subscription 自動處理) 或執行導航
            await MainActor.run {
                ToastManager.shared.showToast(message: "成功加入組織！", type: .success)
            }
            return orgId
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast(message: "加入失敗：\(error.localizedDescription)", type: .error)
            }
            throw error
        }
    }
}
