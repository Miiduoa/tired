import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - ResourceList ViewModel

class ResourceListViewModel: ObservableObject {
    @Published var resources: [Resource] = []
    @Published var categories: [String] = []
    @Published var canManage = false

    let appInstanceId: String
    let organizationId: String
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(appInstanceId: String, organizationId: String) {
        self.appInstanceId = appInstanceId
        self.organizationId = organizationId
        setupSubscriptions()
        checkPermissions()
    }

    private func setupSubscriptions() {
        FirebaseManager.shared.db
            .collection("resources")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error fetching resources: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.resources = []
                    return
                }

                self.resources = documents.compactMap { doc -> Resource? in
                    try? doc.data(as: Resource.self)
                }

                // Extract unique categories
                self.categories = Array(Set(self.resources.compactMap { $0.category })).sorted()
            }
    }

    private func checkPermissions() {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: organizationId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.canManage = membership.role == .owner || membership.role == .admin || membership.role == .staff
                    }
                }
            } catch {
                print("❌ Error checking permissions: \(error)")
            }
        }
    }

    func createResource(title: String, description: String?, type: ResourceType, url: String, category: String?, tags: [String]?) async throws {
        guard let userId = userId else {
            throw NSError(domain: "ResourceListViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let resource = Resource(
            orgAppInstanceId: appInstanceId,
            organizationId: organizationId,
            title: title,
            description: description,
            type: type,
            url: url,
            category: category,
            tags: tags,
            createdByUserId: userId
        )

        _ = try FirebaseManager.shared.db.collection("resources").addDocument(from: resource)
    }

    func deleteResource(_ resource: Resource) async {
        guard let resourceId = resource.id else { return }

        do {
            try await FirebaseManager.shared.db.collection("resources").document(resourceId).delete()
        } catch {
            print("❌ Error deleting resource: \(error)")
        }
    }
}
