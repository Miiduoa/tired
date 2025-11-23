import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Tasks Stats ViewModel

class TasksStatsViewModel: ObservableObject {
    @Published var completedCount = 0
    @Published var pendingCount = 0
    @Published var totalEstimatedMinutes = 0
    @Published var schoolCount = 0
    @Published var workCount = 0
    @Published var clubCount = 0
    @Published var personalCount = 0

    private var cancellables = Set<AnyCancellable>()
    private let db = FirebaseManager.shared.db

    var formattedEstimatedTime: String {
        let hours = totalEstimatedMinutes / 60
        let minutes = totalEstimatedMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours) 小時 \(minutes) 分鐘"
        } else if hours > 0 {
            return "\(hours) 小時"
        } else {
            return "\(minutes) 分鐘"
        }
    }

    init() {
        loadStats()
    }

    private func loadStats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Get start of current week
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        // Listen to user's tasks
        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                let tasks = documents.compactMap { try? $0.data(as: Task.self) }

                // Filter tasks for this week
                let weekTasks = tasks.filter { task in
                    if let plannedDate = task.plannedDate {
                        return plannedDate >= startOfWeek
                    }
                    if let deadline = task.deadlineAt {
                        return deadline >= startOfWeek
                    }
                    return !task.isDone
                }

                // Calculate stats
                self.completedCount = weekTasks.filter { $0.isDone }.count
                self.pendingCount = weekTasks.filter { !$0.isDone }.count
                self.totalEstimatedMinutes = weekTasks.filter { !$0.isDone }.compactMap { $0.estimatedMinutes }.reduce(0, +)

                // Category stats (all pending tasks)
                let pendingTasks = tasks.filter { !$0.isDone }
                self.schoolCount = pendingTasks.filter { $0.category == .school }.count
                self.workCount = pendingTasks.filter { $0.category == .work }.count
                self.clubCount = pendingTasks.filter { $0.category == .club }.count
                self.personalCount = pendingTasks.filter { $0.category == .personal }.count
            }
    }
}
