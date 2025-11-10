import Foundation
import SwiftUI

// MARK: - Backlog View Model
@MainActor
class BacklogViewModel: ObservableObject {

    @Published var tasks: [Task] = []
    @Published var selectedTask: Task?
    @Published var showQuickAdd: Bool = false
    @Published var isLoading: Bool = false

    private let taskService = TaskService.shared
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared

    func loadTasks() async {
        isLoading = true

        do {
            guard let userId = FirebaseService.shared.currentUser?.uid else {
                isLoading = false
                return
            }

            let profile = try await profileService.getProfile(userId: userId)
            let currentTerm: TermConfig? = if let termId = profile?.currentTermId {
                try await termService.getTermByTermId(userId: userId, termId: termId)
            } else {
                nil
            }

            tasks = try await taskService.getBacklogTasks(
                userId: userId,
                termConfig: currentTerm
            )

        } catch {
            print("❌ Error loading backlog tasks: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func completeTask(_ task: Task) async {
        do {
            try await taskService.completeTask(task)
            await loadTasks()
        } catch {
            print("❌ Error completing task: \(error.localizedDescription)")
        }
    }
}
