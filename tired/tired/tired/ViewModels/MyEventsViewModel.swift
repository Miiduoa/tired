import SwiftUI
import Combine
import FirebaseAuth

// MARK: - My Events ViewModel

class MyEventsViewModel: ObservableObject {
    @Published var events: [EventWithRegistration] = []
    @Published var isLoading = true

    private let eventService = EventService()

    init() {
        _Concurrency.Task {
            await loadEvents()
        }
    }

    func loadEvents() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoading = false }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            let events = try await eventService.fetchUserRegisteredEvents(userId: userId)
            await MainActor.run {
                self.events = events.sorted { $0.event.startAt > $1.event.startAt }
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading events: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}
