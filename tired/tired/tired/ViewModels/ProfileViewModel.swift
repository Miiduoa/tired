import Foundation
import Combine
import Firebase

/// 個人資料頁面的 ViewModel，用於獲取綜合統計數據
class ProfileViewModel: ObservableObject {
    @Published var totalTasksCompleted: Int = 0
    @Published var totalEventsAttended: Int = 0
    @Published var memberSince: Date?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let taskService = TaskService()
    private let eventService = EventService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var creationDate: Date? {
        Auth.auth().currentUser?.metadata.creationDate
    }

    init() {
        self.memberSince = creationDate
        fetchStats()
    }

    func fetchStats() {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            return
        }

        isLoading = true
        
        // 獲取已完成的任務
        let tasksPublisher = Future<[tired.Task], Error> { promise in
            Swift.Task {
                do {
                    let snapshot = try await self.db.collection("tasks")
                        .whereField("userId", isEqualTo: userId)
                        .whereField("isDone", isEqualTo: true)
                        .getDocuments()
                    let tasks = snapshot.documents.compactMap { try? $0.data(as: tired.Task.self) }
                    promise(.success(tasks))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()


        // 獲取所有已結束的已報名活動
        let eventsPublisher = Future<[EventWithRegistration], Error> { promise in
            Swift.Task {
                do {
                    let allRegisteredEvents = try await self.eventService.fetchUserRegisteredEvents(userId: userId)
                    let attendedEvents = allRegisteredEvents.filter { $0.event.startAt < Date() }
                    promise(.success(attendedEvents))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
        
        Publishers.Zip2(tasksPublisher, eventsPublisher)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "讀取統計資料失敗: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] (completedTasks, attendedEvents) in
                self?.totalTasksCompleted = completedTasks.count
                self?.totalEventsAttended = attendedEvents.count
            })
            .store(in: &cancellables)
    }
    
    // 輔助屬性，用於獲取 db 實例
    private var db: Firestore {
        FirebaseManager.shared.db
    }
}
