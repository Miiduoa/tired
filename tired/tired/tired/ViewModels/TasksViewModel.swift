import Foundation
import Combine
import FirebaseAuth

/// 任务视图的ViewModel
class TasksViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var weekTasks: [Task] = []
    @Published var backlogTasks: [Task] = []
    @Published var isLoading = false
    @Published var selectedCategory: TaskCategory?

    private let taskService = TaskService()
    private let autoPlanService = AutoPlanService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let userId = userId else { return }

        // 今天的任务
        taskService.fetchTodayTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching today tasks: \(error)")
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.todayTasks = tasks
                }
            )
            .store(in: &cancellables)

        // 本周的任务
        taskService.fetchWeekTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching week tasks: \(error)")
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.weekTasks = tasks
                }
            )
            .store(in: &cancellables)

        // Backlog任务
        taskService.fetchBacklogTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching backlog tasks: \(error)")
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.backlogTasks = tasks
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func toggleTaskDone(task: Task) {
        guard let id = task.id else { return }

        _Concurrency.Task {
            do {
                try await taskService.toggleTaskDone(id: id, isDone: !task.isDone)
            } catch {
                print("❌ Error toggling task: \(error)")
            }
        }
    }

    func deleteTask(task: Task) {
        guard let id = task.id else { return }

        _Concurrency.Task {
            do {
                try await taskService.deleteTask(id: id)
            } catch {
                print("❌ Error deleting task: \(error)")
            }
        }
    }

    func createTask(title: String, category: TaskCategory, deadline: Date?, estimatedMinutes: Int?) {
        guard let userId = userId else { return }

        let task = Task(
            userId: userId,
            title: title,
            category: category,
            deadlineAt: deadline,
            estimatedMinutes: estimatedMinutes
        )

        _Concurrency.Task {
            do {
                try await taskService.createTask(task)
            } catch {
                print("❌ Error creating task: \(error)")
            }
        }
    }

    func updateTask(_ task: Task) {
        _Concurrency.Task {
            do {
                try await taskService.updateTask(task)
            } catch {
                print("❌ Error updating task: \(error)")
            }
        }
    }

    // MARK: - Auto Plan

    func runAutoplan(weeklyCapacity: Int = 600) {
        _Concurrency.Task { @MainActor in
            isLoading = true
        }

        _Concurrency.Task {
            defer {
                _Concurrency.Task { @MainActor in
                    isLoading = false
                }
            }

            // 获取所有任务
            let allTasks = await MainActor.run {
                todayTasks + weekTasks + backlogTasks
            }

            // 运行autoplan
            let options = AutoPlanService.AutoPlanOptions(
                weeklyCapacityMinutes: weeklyCapacity
            )
            let updatedTasks = autoPlanService.autoplanWeek(tasks: allTasks, options: options)

            // 批量更新
            do {
                try await taskService.batchUpdateTasks(updatedTasks)
            } catch {
                print("❌ Error running autoplan: \(error)")
            }
        }
    }

    // MARK: - Filter

    func filteredTasks(_ tasks: [Task]) -> [Task] {
        guard let category = selectedCategory else { return tasks }
        return tasks.filter { $0.category == category }
    }

    // MARK: - Week Statistics

    func weeklyStatistics() -> [(day: Date, duration: Int)] {
        let weekStart = Date.startOfWeek()
        let days = Date.daysOfWeek(startingFrom: weekStart)

        return days.map { day in
            let duration = autoPlanService.calculateDailyDuration(tasks: weekTasks, for: day)
            return (day, duration)
        }
    }
}
