import Foundation
import Combine
import Firebase

/// 日曆視圖的 ViewModel
class CalendarViewModel: ObservableObject {
    @Published var calendarItems: [Date: [CalendarItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var allEvents: [Event] = [] // Store raw events
    @Published var allTasks: [Task] = []   // Store raw tasks
    
    private let eventService = EventService()
    private let taskService = TaskService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // Reference to TasksViewModel for consistency, e.g., if TaskDetailView requires it
    @Published var tasksViewModel: TasksViewModel // This should probably be injected or created at a higher level
    
    init() {
        // Initialize tasksViewModel here or inject it if it's shared across tabs
        // For simplicity and to allow TaskDetailView to function, we'll create one.
        // In a real app, you might want to share this instance if it holds global state.
        self.tasksViewModel = TasksViewModel() 
        fetchData()
    }

    func fetchData() {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            ToastManager.shared.showToast(message: "用戶未登入，請先登入。", type: .error)
            return
        }

        isLoading = true
        
        // 使用 Combine 的 `zip` 來並行處理兩個非同步操作
        let eventsPublisher = Future<[EventWithRegistration], Error> { promise in
            _Concurrency.Task {
                do {
                    let events = try await self.eventService.fetchUserRegisteredEvents(userId: userId)
                    promise(.success(events))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
        
        let tasksPublisher = taskService.fetchActiveTasks(userId: userId)
            .first() // 我們只需要獲取一次任務列表，而不是持續監聽

        Publishers.Zip(eventsPublisher, tasksPublisher)
            .flatMap { (eventsWithReg, tasks) -> AnyPublisher<([EventWithRegistration], [Task], [String: Organization]), Error> in
                // 從任務中收集所有需要的組織 ID
                let orgIdsFromTasks = Set(tasks.compactMap { $0.sourceOrgId })
                
                // 批次獲取組織資訊
                return Future<([EventWithRegistration], [Task], [String: Organization]), Error> { promise in
                    _Concurrency.Task {
                        do {
                            let orgs = try await self.organizationService.fetchOrganizations(ids: Array(orgIdsFromTasks))
                            promise(.success((eventsWithReg, tasks, orgs)))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }.eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // self?.errorMessage = "讀取日曆資料失敗: \(error.localizedDescription)" // Replaced by Toast
                    ToastManager.shared.showToast(message: "讀取日曆資料失敗: \(error.localizedDescription)", type: .error)
                    print("❌ Error fetching calendar data: \(error)")
                }
            }, receiveValue: { [weak self] (eventsWithReg, tasks, orgs) in
                guard let self = self else { return }
                
                self.allEvents = eventsWithReg.map { $0.event } // Store raw events
                self.allTasks = tasks                            // Store raw tasks

                // 轉換 Event 為 CalendarItem
                let eventItems = eventsWithReg.map { CalendarItem(from: $0.event, organization: $0.organization) }
                
                // 轉換 Task 為 CalendarItem
                let taskItems = tasks
                    .filter { $0.deadlineAt != nil || $0.plannedDate != nil } // 只顯示有日期資訊的任務
                    .map { task -> CalendarItem in
                        let organization = task.sourceOrgId.flatMap { orgs[$0] }
                        return CalendarItem(from: task, organization: organization)
                    }
                
                let allItems = eventItems + taskItems
                
                // 將所有項目按日期分組
                self.calendarItems = Dictionary(grouping: allItems) { item in
                    return Calendar.current.startOfDay(for: item.date)
                }
                print("✅ Calendar data loaded successfully. \(self.calendarItems.count) days with items.")
            })
            .store(in: &cancellables)
    }
    
    // Helper function to get a Task by ID
    func getTask(by id: String) -> Task? {
        allTasks.first(where: { $0.id == id })
    }

    // Helper function to get an Event by ID
    func getEvent(by id: String) -> Event? {
        allEvents.first(where: { $0.id == id })
    }
}
