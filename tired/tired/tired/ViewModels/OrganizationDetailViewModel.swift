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
    
    private let organizationId: String
    private let postService = PostService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(organizationId: String) {
        self.organizationId = organizationId
        _Concurrency.Task {
            await fetchOrganization()
            setupSubscriptions()
            checkMembership()
            checkRequestStatus()
        }
    }

    private func fetchOrganization() async {
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

    func leaveOrganization() {
        guard let membershipId = currentMembership?.id else { return }

        _Concurrency.Task {
            do {
                try await organizationService.deleteMembership(id: membershipId)
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
    
    // MARK: - App Management
    func enableApp(templateKey: OrgAppTemplateKey) {
        _Concurrency.Task {
            // ... implementation ...
        }
    }

    func disableApp(appInstance: OrgAppInstance) {
        // ... implementation ...
    }

    // MARK: - Permissions
    var canManageMembers: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.manageMembers, in: org)
    }

    var canManageApps: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.manageApps, in: org)
    }

    var canChangeRoles: Bool {
        guard let membership = currentMembership, let org = organization else { return false }
        return membership.hasPermission(.changeRoles, in: org)
    }
}

