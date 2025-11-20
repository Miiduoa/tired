import Foundation
import Combine
import FirebaseAuth

/// 任務視圖的ViewModel
class TasksViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var weekTasks: [Task] = []
    @Published var backlogTasks: [Task] = []
    @Published var isLoading = false
    @Published var selectedCategory: TaskCategory?
    @Published var sortOption: TaskSortOption = .deadline

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

    // MARK: - Filter & Sort

    func filteredTasks(_ tasks: [Task]) -> [Task] {
        var filtered = tasks

        // 篩選分類
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }

        // 排序
        return sortTasks(filtered)
    }

    private func sortTasks(_ tasks: [Task]) -> [Task] {
        switch sortOption {
        case .deadline:
            return tasks.sorted { t1, t2 in
                // 有截止時間的優先，然後按時間排序
                if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
                    return d1 < d2
                }
                if t1.deadlineAt != nil { return true }
                if t2.deadlineAt != nil { return false }
                return t1.createdAt < t2.createdAt
            }
        case .priority:
            return tasks.sorted { t1, t2 in
                if t1.priority != t2.priority {
                    return t1.priority.rawValue > t2.priority.rawValue
                }
                return t1.createdAt < t2.createdAt
            }
        case .category:
            return tasks.sorted { t1, t2 in
                if t1.category != t2.category {
                    return t1.category.rawValue < t2.category.rawValue
                }
                return t1.createdAt < t2.createdAt
            }
        case .created:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        }
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

// MARK: - Task Sort Option

enum TaskSortOption: String, CaseIterable {
    case deadline = "截止時間"
    case priority = "優先級"
    case category = "分類"
    case created = "創建時間"

    var icon: String {
        switch self {
        case .deadline: return "calendar"
        case .priority: return "flag.fill"
        case .category: return "tag.fill"
        case .created: return "clock.fill"
        }
    }
}
