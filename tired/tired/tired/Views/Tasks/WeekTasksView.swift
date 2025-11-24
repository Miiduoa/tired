import SwiftUI

@available(iOS 17.0, *)
struct WeekTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let stats = viewModel.weeklyStatistics()
        let tasks = viewModel.filteredTasks(viewModel.weekTasks)

        VStack(spacing: AppDesignSystem.paddingMedium) {
            // Weekly capacity indicator
            WeeklyCapacityView(stats: stats, dailyCapacity: viewModel.userProfile?.dailyCapacityMinutes ?? 120)

            // Daily sections
            ForEach(stats, id: \.day) { stat in
                let dayTasks = tasks.filter { task in
                    guard let planned = task.plannedDate else { return false }
                    return Calendar.current.isDate(planned, equalTo: stat.day, toGranularity: .day)
                }

                DayTasksCard(
                    date: stat.day,
                    duration: stat.duration,
                    tasks: dayTasks,
                    onToggle: { task in
                        viewModel.toggleTaskDone(task: task)
                    }
                )
            }
        }
    }
}
