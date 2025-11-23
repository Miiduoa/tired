import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - TaskBoard ViewModel

class TaskBoardViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var canManage = false

    let appInstanceId: String
    let organizationId: String
    private let taskService = TaskService()
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
        // 獲取組織任務（sourceType = org_task, sourceAppInstanceId = appInstanceId）
        FirebaseManager.shared.db
            .collection("tasks")
            .whereField("sourceAppInstanceId", isEqualTo: appInstanceId)
            .whereField("sourceType", isEqualTo: TaskSourceType.orgTask.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching org tasks: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let tasks = documents.compactMap { doc -> Task? in
                    try? doc.data(as: Task.self)
                }

                DispatchQueue.main.async {
                    self?.tasks = tasks
                }
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
                        self.canManage = membership.role == .owner || membership.role == .admin
                    }
                }
            } catch {
                print("❌ Error checking permissions: \(error)")
            }
        }
    }

    func createOrgTask(title: String, description: String?, category: TaskCategory, deadline: Date?, estimatedMinutes: Int) async throws {
        guard userId != nil else {
            throw NSError(domain: "TaskBoardViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        // 創建組織任務（沒有 userId，或使用特殊標記）
        let task = Task(
            userId: "org_\(organizationId)", // 使用組織ID標記
            sourceOrgId: organizationId,
            sourceAppInstanceId: appInstanceId,
            sourceType: .orgTask,
            title: title,
            description: description,
            category: category,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes
        )

        try await taskService.createTask(task)
    }

    func syncToPersonalTasks(task: Task) {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                // 創建個人任務副本
                var personalTask = task
                personalTask.id = nil // 清除ID以創建新任務
                personalTask.userId = userId
                personalTask.sourceType = .orgTask
                personalTask.plannedDate = nil // 讓用戶自己排程

                try await taskService.createTask(personalTask)

                print("✅ Task synced to personal tasks")
            } catch {
                print("❌ Error syncing task: \(error)")
            }
        }
    }
}
