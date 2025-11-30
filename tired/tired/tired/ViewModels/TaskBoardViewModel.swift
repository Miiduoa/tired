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
            // 使用 OrganizationService 來檢查權限
            let organizationService = OrganizationService()
            
            // 檢查是否有創建任務或管理小應用的權限
            let canCreateTasks = (try? await organizationService.checkPermission(
                userId: userId,
                organizationId: organizationId,
                permission: .createTasks
            )) ?? false
            
            let canManageApps = (try? await organizationService.checkPermission(
                userId: userId,
                organizationId: organizationId,
                permission: .manageApps
            )) ?? false
            
            await MainActor.run {
                self.canManage = canCreateTasks || canManageApps
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

        _ = try await taskService.createTask(task)
    }

    func syncToPersonalTasks(task: Task) async throws {
        guard let userId = userId else {
            throw NSError(domain: "TaskBoardViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        // 創建個人任務副本
        var personalTask = task
        personalTask.id = nil // 清除ID以創建新任務
        personalTask.userId = userId
        personalTask.sourceType = .orgTask
        personalTask.plannedDate = nil // 讓用戶自己排程

        _ = try await taskService.createTask(personalTask)

        print("✅ Task synced to personal tasks")
    }

    /// 非同步版本，回傳成功/失敗給 UI
    func syncToPersonalTasksAsync(task: Task) async -> Bool {
        do {
            try await syncToPersonalTasks(task: task)
            await MainActor.run { ToastManager.shared.showToast(message: "任務同步成功！", type: .success) }
            return true
        } catch {
            print("❌ Error syncing to personal tasks async: \(error)")
            await MainActor.run { ToastManager.shared.showToast(message: "同步失敗：\(error.localizedDescription)", type: .error) }
            return false
        }
    }
}
