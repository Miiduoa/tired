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
        guard let userId = userId else { return }

        _Concurrency.Task {
            for event in events {
                guard let eventId = event.id else { continue }

                // 檢查是否已報名
                let isReg = (try? await eventService.isUserRegistered(eventId: eventId, userId: userId)) ?? false

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
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: organizationId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.canManage = membership.role == .owner || membership.role == .admin
                    }
                }
            } catch {
                print("❌ Error checking permissions: \(error)")
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
    }

    func registerForEvent(event: Event) {
        guard let userId = userId, let eventId = event.id else { return }

        _Concurrency.Task {
            do {
                try await eventService.registerForEvent(eventId: eventId, userId: userId)

                await MainActor.run {
                    self.registrations[eventId] = true
                    self.registrationCounts[eventId] = (self.registrationCounts[eventId] ?? 0) + 1
                }

                // TODO: 可選：自動創建任務到個人任務中樞
            } catch {
                print("❌ Error registering for event: \(error)")
            }
        }
    }

    func cancelRegistration(event: Event) {
        guard let userId = userId, let eventId = event.id else { return }

        _Concurrency.Task {
            do {
                try await eventService.cancelRegistration(eventId: eventId, userId: userId)

                await MainActor.run {
                    self.registrations[eventId] = false
                    self.registrationCounts[eventId] = max(0, (self.registrationCounts[eventId] ?? 1) - 1)
                }
            } catch {
                print("❌ Error canceling registration: \(error)")
            }
        }
    }
}
