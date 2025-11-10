import Foundation
import SwiftUI

// MARK: - Task Detail View Model
@MainActor
class TaskDetailViewModel: ObservableObject {

    @Published var task: Task
    @Published var editedTask: Task
    @Published var isEditing: Bool = false

    @Published var blockedByTasks: [Task] = []
    @Published var blockingTasks: [Task] = []

    @Published var showAddEvidence: Bool = false
    @Published var showDeleteConfirm: Bool = false
    @Published var showFocusMode: Bool = false

    private let taskService = TaskService.shared
    private let profileService = UserProfileService.shared

    var canUseSchoolCategory: Bool {
        // Check if onboarding is complete
        guard let userId = FirebaseService.shared.currentUser?.uid else { return false }
        // In a real implementation, we'd check the profile
        // For now, we'll allow it
        return true
    }

    init(task: Task) {
        self.task = task
        self.editedTask = task
    }

    // MARK: - Load Dependencies

    func loadDependencies() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }

        do {
            let allTasks = try await taskService.getTasks(userId: userId)

            blockedByTasks = task.blockedByTaskIds.compactMap { id in
                allTasks.first { $0.id == id && $0.deletedAt == nil }
            }

            blockingTasks = task.blockingTaskIds.compactMap { id in
                allTasks.first { $0.id == id && $0.deletedAt == nil }
            }

        } catch {
            print("❌ Error loading dependencies: \(error.localizedDescription)")
        }
    }

    // MARK: - Edit Mode

    func startEdit() {
        editedTask = task
        isEditing = true
    }

    func cancelEdit() {
        editedTask = task
        isEditing = false
    }

    func saveChanges() async {
        do {
            try await taskService.updateTask(editedTask)
            task = editedTask
            isEditing = false
            ToastManager.shared.showSuccess("任務已儲存")
        } catch {
            print("❌ Error saving task: \(error.localizedDescription)")
            ToastManager.shared.showError("儲存失敗")
        }
    }

    // MARK: - Task Actions

    func toggleFocus() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }

        do {
            let allTasks = try await taskService.getTasks(userId: userId)
            let newFocusState = !task.isTodayFocus
            _ = try await taskService.setTodayFocus(
                task,
                isFocus: newFocusState,
                todayDate: Date(),
                allTasks: allTasks
            )

            // Reload task
            if let updated = try await taskService.getTask(id: task.id) {
                task = updated
                editedTask = updated
            }

            if newFocusState {
                ToastManager.shared.showSuccess("已設為今日專注")
            } else {
                ToastManager.shared.showInfo("已取消今日專注")
            }
        } catch {
            print("❌ Error toggling focus: \(error.localizedDescription)")
            ToastManager.shared.showError("專注設定失敗")
        }
    }

    func startFocus() async {
        showFocusMode = true
    }

    func deleteTask() async {
        do {
            try await taskService.deleteTask(id: task.id)
            ToastManager.shared.showSuccess("任務已刪除")
        } catch {
            print("❌ Error deleting task: \(error.localizedDescription)")
            ToastManager.shared.showError("刪除失敗")
        }
    }

    // MARK: - Evidence Management

    func addEvidence(_ evidence: TaskEvidence) async {
        do {
            try await taskService.addEvidence(task, evidence: evidence)

            // Reload task
            if let updated = try await taskService.getTask(id: task.id) {
                task = updated
                editedTask = updated
            }

            ToastManager.shared.showSuccess("佐證已新增")
        } catch {
            print("❌ Error adding evidence: \(error.localizedDescription)")
            ToastManager.shared.showError("新增佐證失敗")
        }
    }

    func deleteEvidence(_ evidence: TaskEvidence) async {
        do {
            try await taskService.removeEvidence(task, evidenceId: evidence.id)

            // Reload task
            if let updated = try await taskService.getTask(id: task.id) {
                task = updated
                editedTask = updated
            }

            ToastManager.shared.showSuccess("佐證已刪除")
        } catch {
            print("❌ Error deleting evidence: \(error.localizedDescription)")
            ToastManager.shared.showError("刪除佐證失敗")
        }
    }
}
