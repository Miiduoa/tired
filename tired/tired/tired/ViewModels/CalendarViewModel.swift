import Foundation
import Combine
import Firebase

/// 日曆視圖的 ViewModel
class CalendarViewModel: ObservableObject {
    @Published var calendarItems: [Date: [CalendarItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let eventService = EventService()
    private let taskService = TaskService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        fetchData()
    }

    func fetchData() {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            return
        }

        isLoading = true
        
        // 使用 Combine 的 `zip` 來並行處理兩個非同步操作
        let eventsPublisher = Future<[EventWithRegistration], Error> { promise in
            Task {
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
                let orgIdsFromTasks = Set(tasks.map { $0.organizationId })
                
                // 批次獲取組織資訊
                return Future<([EventWithRegistration], [Task], [String: Organization]), Error> { promise in
                    Task {
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
                    self?.errorMessage = "讀取日曆資料失敗: \(error.localizedDescription)"
                    print("❌ Error fetching calendar data: \(error)")
                }
            }, receiveValue: { [weak self] (eventsWithReg, tasks, orgs) in
                guard let self = self else { return }
                
                // 轉換 Event 為 CalendarItem
                let eventItems = eventsWithReg.map { CalendarItem(from: $0.event, organization: $0.organization) }
                
                // 轉換 Task 為 CalendarItem
                let taskItems = tasks
                    .filter { $0.dueDate != nil } // 只顯示有截止日期的任務
                    .map { task -> CalendarItem in
                    let organization = orgs[task.organizationId]
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
}
