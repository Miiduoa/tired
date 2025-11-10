import Foundation
import SwiftUI

// MARK: - Today View Model
@MainActor
class TodayViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var allTodayTasks: [Task] = []
    @Published var overdueDeadlineTasks: [Task] = []
    @Published var deadlineTodayTasks: [Task] = []
    @Published var workDateDelayedTasks: [Task] = []
    @Published var todayListTasks: [Task] = []
    @Published var focusTasks: [Task] = []

    @Published var selectedTask: Task?
    @Published var isLoading: Bool = false

    // Services
    private let taskService = TaskService.shared
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared

    private var userProfile: UserProfile?
    private var currentTerm: TermConfig?

    // MARK: - Load Tasks

    func loadTasks() async {
        isLoading = true

        do {
            // Get user profile and term
            guard let userId = FirebaseService.shared.currentUser?.uid else {
                isLoading = false
                return
            }

            userProfile = try await profileService.getProfile(userId: userId)

            if let termId = userProfile?.currentTermId {
                currentTerm = try await termService.getTermByTermId(userId: userId, termId: termId)
            }

            // Get today's tasks
            let todayDate = Date()
            let tasks = try await taskService.getTodayTasks(
                userId: userId,
                todayDate: todayDate,
                termConfig: currentTerm
            )

            // Sort tasks
            allTodayTasks = sortTasks(tasks)

            // Categorize into four sections
            categorizeTasksIntoSections(todayDate: todayDate)

        } catch {
            print("❌ Error loading tasks: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Categorize Tasks

    private func categorizeTasksIntoSections(todayDate: Date) {
        var overdue: [Task] = []
        var deadlineToday: [Task] = []
        var delayed: [Task] = []
        var todayList: [Task] = []

        for task in allTodayTasks {
            // Check each condition in priority order
            if let deadline = task.deadlineAt {
                let deadlineDateOnly = DateUtils.startOfDay(deadline)
                let todayDateOnly = DateUtils.startOfDay(todayDate)

                if DateUtils.isBefore(deadlineDateOnly, todayDateOnly) {
                    // 1. Overdue deadline
                    overdue.append(task)
                    continue
                } else if DateUtils.isSameDay(deadline, todayDate) {
                    // 2. Deadline today
                    deadlineToday.append(task)
                    continue
                }
            }

            if let plannedDate = task.plannedWorkDate {
                if DateUtils.isBefore(plannedDate, todayDate) {
                    // 3. Work date delayed
                    delayed.append(task)
                    continue
                } else if DateUtils.isSameDay(plannedDate, todayDate) {
                    // 4. Today's list
                    todayList.append(task)
                    continue
                }
            }

            // If none of the above, put in today's list
            todayList.append(task)
        }

        overdueDeadlineTasks = sortTasks(overdue)
        deadlineTodayTasks = sortTasks(deadlineToday)
        workDateDelayedTasks = sortTasks(delayed)
        todayListTasks = sortTasks(todayList)

        // Focus tasks
        focusTasks = allTodayTasks.filter { $0.isTodayFocus }
    }

    // MARK: - Sort Tasks

    private func sortTasks(_ tasks: [Task]) -> [Task] {
        return tasks.sorted { t1, t2 in
            // Focus first
            if t1.isTodayFocus && !t2.isTodayFocus { return true }
            if !t1.isTodayFocus && t2.isTodayFocus { return false }

            // Priority
            if t1.priority.sortOrder != t2.priority.sortOrder {
                return t1.priority.sortOrder < t2.priority.sortOrder
            }

            // Deadline
            if let d1 = t1.deadlineDate, let d2 = t2.deadlineDate, d1 != d2 {
                return d1 < d2
            }

            // Planned work date
            if let p1 = t1.plannedWorkDate, let p2 = t2.plannedWorkDate,
               !DateUtils.isSameDay(p1, p2) {
                return DateUtils.isBefore(p1, p2)
            }

            // Created at
            return t1.createdAt < t2.createdAt
        }
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task) async {
        do {
            try await taskService.completeTask(task)
            ToastManager.shared.showSuccess("任務「\(task.title)」已完成")
            await loadTasks()
        } catch {
            print("❌ Error completing task: \(error.localizedDescription)")
            ToastManager.shared.showError("完成任務失敗")
        }
    }

    func toggleFocus(_ task: Task) async {
        do {
            let newFocusState = !task.isTodayFocus
            _ = try await taskService.setTodayFocus(
                task,
                isFocus: newFocusState,
                todayDate: Date(),
                allTasks: allTodayTasks
            )

            if newFocusState {
                ToastManager.shared.showSuccess("已設為今日專注")
            } else {
                ToastManager.shared.showInfo("已取消今日專注")
            }

            await loadTasks()
        } catch {
            print("❌ Error toggling focus: \(error.localizedDescription)")
            ToastManager.shared.showError("專注設定失敗")
        }
    }
}
