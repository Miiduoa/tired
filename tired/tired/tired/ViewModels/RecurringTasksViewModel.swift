import Foundation
import Combine
import FirebaseAuth

@MainActor
class RecurringTasksViewModel: ObservableObject {
    @Published var recurringTasks: [RecurringTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service = RecurringTaskService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchRecurringTasks()
    }
    
    func fetchRecurringTasks() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "用戶未登入"
            return
        }
        
        isLoading = true
        service.fetchRecurringTasks(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] tasks in
                self?.recurringTasks = tasks
                self?.errorMessage = nil
            })
            .store(in: &cancellables)
    }
    
    func deleteRecurringTask(_ task: RecurringTask) {
        guard let id = task.id else { return }
        
        _Concurrency.Task {
            do {
                try await service.deleteRecurringTask(id: id)
                await MainActor.run {
                    ToastManager.shared.showToast(message: "週期任務已刪除", type: .success)
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast(message: "刪除失敗：\(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    func togglePause(_ task: RecurringTask) {
        guard let id = task.id else { return }
        let isPausing = !task.isPaused
        
        _Concurrency.Task {
            do {
                try await service.togglePause(for: id)
                await MainActor.run {
                    let message = isPausing ? "任務已暫停" : "任務已恢復"
                    ToastManager.shared.showToast(message: message, type: .success)
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast(message: "操作失敗：\(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    func generateNow(_ task: RecurringTask) {
        guard let id = task.id else { return }
        
        _Concurrency.Task {
            do {
                try await service.generateInstancesManually(for: id)
                await MainActor.run {
                    ToastManager.shared.showToast(message: "已生成新任務實例", type: .success)
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast(message: "生成失敗：\(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}
