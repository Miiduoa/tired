import Foundation
import EventKit
import Combine

// Represents a block of time that is already occupied by an external event.
struct BusyTimeBlock: Hashable {
    var start: Date
    var end: Date
}

/// A service to interact with the user's calendar using EventKit.
class CalendarService {
    private let eventStore = EKEventStore()

    /// Checks the current authorization status for calendar access.
    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .authorized
    }

    /// Requests access to the user's calendar.
    /// - Returns: A boolean indicating whether access was granted.
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted
            } catch {
                print("❌ Error requesting full calendar access: \(error)")
                return false
            }
        } else {
            // Fallback for older iOS versions
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        print("❌ Error requesting calendar access: \(error)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Fetches all calendar events for a given date range and returns them as an array of `BusyTimeBlock`.
    /// - Parameter forNextDays: The number of days from today to fetch events for.
    /// - Returns: An array of `BusyTimeBlock` representing the user's schedule, or an empty array if not authorized or no events.
    func fetchBusyTimeBlocks(forNextDays days: Int) async -> [BusyTimeBlock] {
        guard isAuthorized else {
            print("⚠️ Not authorized to access calendar.")
            return []
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: days, to: startDate) else {
            return []
        }

        // Create a predicate to fetch events within the date range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)

        // Fetch the events
        let events = eventStore.events(matching: predicate)

        // Convert EKEvent to BusyTimeBlock
        return events.map { event in
            BusyTimeBlock(start: event.startDate, end: event.endDate)
        }
    }
}
