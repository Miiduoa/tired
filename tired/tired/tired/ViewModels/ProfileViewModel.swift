import Foundation
import Combine
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 個人資料頁面的 ViewModel，用於獲取綜合統計數據
class ProfileViewModel: ObservableObject {
    @Published var totalTasksCompleted: Int = 0
    @Published var totalEventsAttended: Int = 0
    @Published var userProfile: UserProfile? // New: to store the profile of the user being viewed
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let taskService = TaskService()
    private let eventService = EventService()
    private let userService = UserService() // New: to fetch user profile
    private var cancellables = Set<AnyCancellable>()

    // The userId this ViewModel is currently focused on
    private var currentUserId: String?
    
    // The currently authenticated user's ID
    private var authenticatedUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init(userId: String? = nil) {
        // If a userId is provided, view that user's profile, otherwise view current user's profile
        self.currentUserId = userId ?? authenticatedUserId
        fetchStatsAndProfile()
    }

    func fetchStatsAndProfile() {
        guard let fetchUserId = currentUserId else {
            errorMessage = "用戶未登入或無法獲取用戶ID"
            ToastManager.shared.showToast(message: "用戶未登入或無法獲取用戶ID", type: .error)
            return
        }

        isLoading = true
        errorMessage = nil // Clear previous errors
        
        // Fetch user profile first
        let profilePublisher = Future<UserProfile?, Error> { promise in
            _Concurrency.Task {
                do {
                    let profile = try await self.userService.fetchUserProfile(userId: fetchUserId)
                    promise(.success(profile))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
        
        // Fetch completed tasks
        let tasksPublisher = Future<[Task], Error> { promise in
            _Concurrency.Task {
                do {
                    let snapshot = try await self.db.collection("tasks")
                        .whereField("userId", isEqualTo: fetchUserId)
                        .whereField("isDone", isEqualTo: true)
                        .getDocuments()
                    let tasks = snapshot.documents.compactMap { try? $0.data(as: Task.self) }
                    promise(.success(tasks))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()

        // Fetch attended events
        let eventsPublisher = Future<[EventWithRegistration], Error> { promise in
            _Concurrency.Task {
                do {
                    let allRegisteredEvents = try await self.eventService.fetchUserRegisteredEvents(userId: fetchUserId)
                    let attendedEvents = allRegisteredEvents.filter { $0.event.startAt < Date() }
                    promise(.success(attendedEvents))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
        
        Publishers.Zip3(profilePublisher, tasksPublisher, eventsPublisher)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "讀取個人資料失敗: \(error.localizedDescription)"
                    ToastManager.shared.showToast(message: "讀取個人資料失敗: \(error.localizedDescription)", type: .error)
                }
            }, receiveValue: { [weak self] (profile: UserProfile?, completedTasks: [Task], attendedEvents: [EventWithRegistration]) in
                self?.userProfile = profile
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
