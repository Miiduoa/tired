import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Organization Detail ViewModel

class OrganizationDetailViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var apps: [OrgAppInstance] = [] // Only enabled apps
    @Published var allApps: [OrgAppInstance] = [] // All apps for management
    @Published var currentMembership: Membership?
    @Published var isMember = false
    @Published var isRequestPending = false
    @Published var requestStatusMessage: String?

    let organization: Organization
    private let postService = PostService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(organization: Organization) {
        self.organization = organization
        setupSubscriptions()
        checkMembership()
        checkRequestStatus()
    }

    private func setupSubscriptions() {
        guard let orgId = organization.id else { return }

        // 訂閱組織貼文
        postService.fetchOrganizationPosts(organizationId: orgId)
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
        guard let orgId = organization.id else { return }

        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("orgAppInstances")
                .whereField("organizationId", isEqualTo: orgId)
                .whereField("isEnabled", isEqualTo: true)
                .getDocuments()

            let apps = snapshot.documents.compactMap { doc -> OrgAppInstance? in
                var app = try? doc.data(as: OrgAppInstance.self)
                app?.id = doc.documentID
                return app
            }

            await MainActor.run {
                self.apps = apps
            }
        } catch {
            print("❌ Error fetching enabled apps: \(error)")
        }
    }
    
    private func fetchAllApps() async {
        guard let orgId = organization.id else { return }

        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("orgAppInstances")
                .whereField("organizationId", isEqualTo: orgId)
                .getDocuments()

            let apps = snapshot.documents.compactMap { doc -> OrgAppInstance? in
                var app = try? doc.data(as: OrgAppInstance.self)
                app?.id = doc.documentID
                return app
            }

            await MainActor.run {
                self.allApps = apps
            }
        } catch {
            print("❌ Error fetching all apps: \(error)")
        }
    }

    private func checkMembership() {
        guard let userId = userId, let orgId = organization.id else { return }

        _Concurrency.Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: orgId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.currentMembership = membership
                        self.isMember = true
                    }
                } else {
                    await MainActor.run {
                        self.isMember = false
                        self.currentMembership = nil
                    }
                }
            } catch {
                print("❌ Error checking membership: \(error)")
            }
        }
    }

    private func checkRequestStatus() {
        guard let userId = userId, let orgId = organization.id, !isMember else { return }

        Task {
            do {
                let snapshot = try await FirebaseManager.shared.db.collection("membershipRequests")
                    .whereField("organizationId", isEqualTo: orgId)
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
        guard let userId = userId, let orgId = organization.id, !isRequestPending else { return }
        
        // 最好是從你的 UserService 獲取當前用戶的 Profile，這裡使用 Firebase 的 displayName 作為備用
        let userName = Auth.auth().currentUser?.displayName ?? "匿名用戶"

        Task {
            do {
                try await organizationService.createMembershipRequest(
                    organizationId: orgId,
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
                await MainActor.run {
                    self.requestStatusMessage = "申請失敗，請稍後再試"
                }
            }
        }
    }

    private func joinOrganization() {
        guard let userId = userId, let orgId = organization.id else { return }

        _Concurrency.Task {
            do {
                let membership = Membership(
                    userId: userId,
                    organizationId: orgId,
                    role: .member
                )

                try await organizationService.createMembership(membership)

                await MainActor.run {
                    self.isMember = true
                }

                checkMembership()
            } catch {
                print("❌ Error joining organization: \(error)")
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
        guard let orgId = organization.id else { return }

        _Concurrency.Task {
            do {
                // Check if it exists but is disabled
                if let existingApp = allApps.first(where: { $0.templateKey == templateKey }) {
                    if let appId = existingApp.id {
                        try await FirebaseManager.shared.db.collection("orgAppInstances").document(appId).updateData(["isEnabled": true])
                    }
                } else {
                    // Create new instance
                    let newApp = OrgAppInstance(
                        organizationId: orgId,
                        templateKey: templateKey,
                        name: templateKey.displayName,
                        isEnabled: true
                    )
                    _ = try FirebaseManager.shared.db.collection("orgAppInstances").addDocument(from: newApp)
                }

                await self.fetchApps()
                await self.fetchAllApps()
            } catch {
                print("❌ Error enabling app \(templateKey.rawValue): \(error)")
            }
        }
    }

    func disableApp(appInstance: OrgAppInstance) {
        guard let appId = appInstance.id else { return }

        _Concurrency.Task {
            do {
                try await FirebaseManager.shared.db.collection("orgAppInstances").document(appId).updateData(["isEnabled": false])
                await self.fetchApps()
                await self.fetchAllApps()
            } catch {
                print("❌ Error disabling app \(appId): \(error)")
            }
        }
    }
}
