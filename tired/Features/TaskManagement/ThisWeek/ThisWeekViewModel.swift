import Foundation
import SwiftUI

// MARK: - This Week View Model
@MainActor
class ThisWeekViewModel: ObservableObject {

    @Published var weekStart: Date
    @Published var allTasks: [Task] = []
    @Published var events: [Event] = []
    @Published var weekSummary: CapacityCalculator.WeekLoadSummary?
    @Published var selectedTask: Task?
    @Published var isLoading: Bool = false

    @Published var unscheduledDeadlineThisWeek: [Task] = []
    @Published var overdueUnscheduled: [Task] = []

    private let taskService = TaskService.shared
    private let eventService = EventService.shared
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared

    private var userProfile: UserProfile?
    private var currentTerm: TermConfig?

    init() {
        self.weekStart = DateUtils.startOfWeek(Date())
    }

    // MARK: - Load Tasks

    func loadTasks() async {
        isLoading = true

        do {
            guard let userId = FirebaseService.shared.currentUser?.uid else {
                isLoading = false
                return
            }

            userProfile = try await profileService.getProfile(userId: userId)

            if let termId = userProfile?.currentTermId {
                currentTerm = try await termService.getTermByTermId(userId: userId, termId: termId)
            }

            // Get open tasks for current term
            let openTasks = try await taskService.getOpenTasks(
                userId: userId,
                termConfig: currentTerm
            )

            // Filter tasks for this week
            let weekEnd = DateUtils.addDays(weekStart, 6)
            allTasks = openTasks.filter { task in
                if let planned = task.plannedWorkDate {
                    return !DateUtils.isBefore(planned, weekStart) &&
                           !DateUtils.isAfter(planned, weekEnd)
                }
                return false
            }

            // Get events for this week
            events = try await eventService.getEventsForWeek(
                userId: userId,
                weekStart: weekStart
            )

            // Calculate week summary
            if let profile = userProfile {
                weekSummary = CapacityCalculator.weekLoadSummary(
                    weekStart: weekStart,
                    profile: profile,
                    tasks: allTasks,
                    events: events
                )
            }

            // Get unscheduled tasks
            categorizeUnscheduledTasks(allOpenTasks: openTasks)

        } catch {
            print("❌ Error loading tasks: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Categorize Unscheduled

    private func categorizeUnscheduledTasks(allOpenTasks: [Task]) {
        let weekEnd = DateUtils.addDays(weekStart, 6)
        let sevenDaysAgo = DateUtils.addDays(Date(), -7)

        // Unscheduled with deadline this week
        unscheduledDeadlineThisWeek = allOpenTasks.filter { task in
            guard task.plannedWorkDate == nil,
                  let deadline = task.deadlineAt else {
                return false
            }

            return !DateUtils.isBefore(deadline, weekStart) &&
                   !DateUtils.isAfter(deadline, weekEnd)
        }

        // Overdue unscheduled (last 7 days)
        overdueUnscheduled = allOpenTasks.filter { task in
            guard task.plannedWorkDate == nil,
                  let deadline = task.deadlineAt else {
                return false
            }

            return DateUtils.isBefore(deadline, Date()) &&
                   !DateUtils.isBefore(deadline, sevenDaysAgo)
        }
    }

    // MARK: - Get Tasks for Date

    func tasks(for date: Date) -> [Task] {
        return allTasks.filter { task in
            guard let planned = task.plannedWorkDate else { return false }
            return DateUtils.isSameDay(planned, date)
        }.sorted { t1, t2 in
            // Focus first
            if t1.isTodayFocus && !t2.isTodayFocus { return true }
            if !t1.isTodayFocus && t2.isTodayFocus { return false }

            // Priority
            if t1.priority.sortOrder != t2.priority.sortOrder {
                return t1.priority.sortOrder < t2.priority.sortOrder
            }

            // Created at
            return t1.createdAt < t2.createdAt
        }
    }

    // MARK: - Load Ratio

    func loadRatio(for date: Date) -> Double {
        guard let profile = userProfile else { return 0 }

        return CapacityCalculator.loadRatio(
            on: date,
            profile: profile,
            tasks: allTasks,
            events: events
        )
    }

    // MARK: - Week Navigation

    func goToPreviousWeek() {
        weekStart = DateUtils.addDays(weekStart, -7)
        Task {
            await loadTasks()
        }
    }

    func goToNextWeek() {
        weekStart = DateUtils.addDays(weekStart, 7)
        Task {
            await loadTasks()
        }
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task) async {
        do {
            try await taskService.completeTask(task)
            await loadTasks()
        } catch {
            print("❌ Error completing task: \(error.localizedDescription)")
        }
    }
}
