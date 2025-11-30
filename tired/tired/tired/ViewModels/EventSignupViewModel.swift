import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - EventSignup ViewModel

class EventSignupViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var registrations: [String: Bool] = [:] // eventId: isRegistered
    @Published var registrationCounts: [String: Int] = [:] // eventId: count
    @Published var canManage = false

    let appInstanceId: String
    let organizationId: String
    private let eventService = EventService()
    private let permissionService = PermissionService() // Inject PermissionService
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(appInstanceId: String, organizationId: String) {
        self.appInstanceId = appInstanceId
        self.organizationId = organizationId
        setupSubscriptions()
        checkPermissions()
    }

    private func setupSubscriptions() {
        eventService.fetchOrganizationEvents(organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] events in
                    self?.events = events
                    self?.loadRegistrationData(for: events)
                }
            )
            .store(in: &cancellables)
    }

    private func loadRegistrationData(for events: [Event]) {
        guard let _ = userId else { return }

        _Concurrency.Task {
            for event in events {
                guard let eventId = event.id else { continue }
                guard let currentUserId = self.userId else { continue } // Use self.userId inside Task

                // 檢查是否已報名
                let isReg = (try? await eventService.isUserRegistered(eventId: eventId, userId: currentUserId)) ?? false

                // 獲取報名人數
                let count = (try? await eventService.getRegistrationCount(eventId: eventId)) ?? 0

                await MainActor.run {
                    self.registrations[eventId] = isReg
                    self.registrationCounts[eventId] = count
                }
            }
        }
    }

    private func checkPermissions() {
        guard let _ = userId else { return }

        _Concurrency.Task {
            // Use PermissionService to check permissions
            let canCreateEvents = (try? await permissionService.hasPermissionForCurrentUser(
                organizationId: organizationId,
                permission: AppPermissions.createEventInOrg
            )) ?? false
            
            // Reusing manageOrgApps permission for general management, adjust if needed
            let canManageApps = (try? await permissionService.hasPermissionForCurrentUser(
                organizationId: organizationId,
                permission: AppPermissions.manageOrgApps
            )) ?? false
            
            await MainActor.run {
                self.canManage = canCreateEvents || canManageApps
            }
        }
    }

    func isRegistered(eventId: String) -> Bool {
        registrations[eventId] ?? false
    }

    func getRegistrationCount(eventId: String) -> Int {
        registrationCounts[eventId] ?? 0
    }

    func createEvent(title: String, description: String?, startAt: Date, endAt: Date, location: String?, capacity: Int?) async throws {
        guard userId != nil else {
            ToastManager.shared.showToast(message: "用戶未登入", type: .error)
            throw NSError(domain: "EventSignupViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // RBAC Check
        do {
            let hasPermission = try await permissionService.hasPermissionForCurrentUser(organizationId: organizationId, permission: AppPermissions.createEventInOrg)
            guard hasPermission else {
                ToastManager.shared.showToast(message: "您沒有權限在此組織中創建活動。", type: .error)
                throw NSError(domain: "EventSignupViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
        } catch {
            ToastManager.shared.showToast(message: "檢查權限失敗: \(error.localizedDescription)", type: .error)
            throw error
        }

        let event = Event(
            orgAppInstanceId: appInstanceId,
            organizationId: organizationId,
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            location: location,
            capacity: capacity
        )

        _ = try await eventService.createEvent(event)
        ToastManager.shared.showToast(message: "活動創建成功！", type: .success)
    }

    func registerForEvent(event: Event) {
        guard let _ = userId, let _ = event.id else {
            ToastManager.shared.showToast(message: "用戶未登入或活動ID無效。", type: .error)
            return
        }
        // Backwards-compatible wrapper to the async version
        _Concurrency.Task {
            _ = await self.registerForEventAsync(event: event)
        }
    }

    func cancelRegistration(event: Event) {
        guard let _ = userId, let _ = event.id else {
            ToastManager.shared.showToast(message: "用戶未登入或活動ID無效。", type: .error)
            return
        }
        // Backwards-compatible wrapper to the async version
        _Concurrency.Task {
            _ = await self.cancelRegistrationAsync(event: event)
        }
    }

    // MARK: - Async helpers
    /// 非同步註冊，回傳是否成功
    func registerForEventAsync(event: Event) async -> Bool {
        guard let userId = userId, let eventId = event.id else {
            await MainActor.run { ToastManager.shared.showToast(message: "用戶未登入或活動ID無效。", type: .error) }
            return false
        }

        do {
            try await eventService.registerForEvent(eventId: eventId, userId: userId)
            await MainActor.run {
                self.registrations[eventId] = true
                self.registrationCounts[eventId] = (self.registrationCounts[eventId] ?? 0) + 1
                ToastManager.shared.showToast(message: "報名成功！", type: .success)
            }
            return true
        } catch {
            print("❌ Error registering for event async: \(error)")
            await MainActor.run {
                ToastManager.shared.showToast(message: "報名失敗：\(error.localizedDescription)", type: .error)
            }
            return false
        }
    }

    /// 非同步取消註冊，回傳是否成功
    func cancelRegistrationAsync(event: Event) async -> Bool {
        guard let userId = userId, let eventId = event.id else {
            await MainActor.run { ToastManager.shared.showToast(message: "用戶未登入或活動ID無效。", type: .error) }
            return false
        }

        do {
            try await eventService.cancelRegistration(eventId: eventId, userId: userId)
            await MainActor.run {
                self.registrations[eventId] = false
                self.registrationCounts[eventId] = max(0, (self.registrationCounts[eventId] ?? 1) - 1)
                ToastManager.shared.showToast(message: "已取消報名。", type: .success)
            }
            return true
        } catch {
            print("❌ Error canceling registration async: \(error)")
            await MainActor.run {
                ToastManager.shared.showToast(message: "取消報名失敗：\(error.localizedDescription)", type: .error)
            }
            return false
        }
    }
}
