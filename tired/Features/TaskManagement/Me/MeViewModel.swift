import Foundation

// MARK: - Me View Model
@MainActor
class MeViewModel: ObservableObject {

    @Published var termCompletedCount: Int = 0
    @Published var showTermSettings: Bool = false
    @Published var showCapacitySettings: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var exportedText: String?

    private let taskService = TaskService.shared
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared
    private let dailyLogService = UserDailyLogService.shared

    func loadStats() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }

        do {
            let profile = try await profileService.getProfile(userId: userId)

            if let termId = profile?.currentTermId,
               let term = try await termService.getTermByTermId(userId: userId, termId: termId) {

                // Get completed tasks for current term
                let allTasks = try await taskService.getTasks(userId: userId)

                let termTasks = allTasks.filter { task in
                    task.state == .done &&
                    task.category == .school &&
                    task.termId == termId
                }

                termCompletedCount = termTasks.count
            }

        } catch {
            print("❌ Error loading stats: \(error.localizedDescription)")
        }
    }

    func exportExperience() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }

        do {
            let profile = try await profileService.getProfile(userId: userId)

            guard let termId = profile?.currentTermId,
                  let term = try await termService.getTermByTermId(userId: userId, termId: termId) else {
                return
            }

            // Get completed tasks
            let allTasks = try await taskService.getTasks(userId: userId)
            let completedTasks = allTasks.filter { $0.state == .done && $0.deletedAt == nil }

            // Get daily logs
            let logs = try await dailyLogService.getLogsForTerm(userId: userId, termConfig: term)
            let highlights = logs.compactMap { $0.highlight }.filter { !$0.isEmpty }

            // Build export text
            var text = "# \(term.displayName) 經歷匯出\n\n"

            text += "## 完成任務統計\n"
            text += "- 總完成：\(completedTasks.count) 個任務\n\n"

            text += "## 任務清單\n\n"
            for task in completedTasks.prefix(20) {
                text += "### \(task.title)\n"
                if !task.description.isEmpty {
                    text += "\(task.description)\n"
                }
                if !task.evidences.isEmpty {
                    text += "\n相關作品/證據：\n"
                    for evidence in task.evidences {
                        text += "- \(evidence.title)"
                        if let url = evidence.url {
                            text += ": \(url)"
                        }
                        text += "\n"
                    }
                }
                text += "\n"
            }

            if !highlights.isEmpty {
                text += "## 每日亮點\n\n"
                for (index, highlight) in highlights.prefix(10).enumerated() {
                    text += "\(index + 1). \(highlight)\n"
                }
            }

            exportedText = text
            showExportSheet = true

        } catch {
            print("❌ Error exporting experience: \(error.localizedDescription)")
        }
    }
}
