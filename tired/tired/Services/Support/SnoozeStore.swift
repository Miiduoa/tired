import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class SnoozeStore: ObservableObject {
    static let shared = SnoozeStore()
    private let storageKey = "SnoozeStore.byUser"
    // userId -> [id: expiry]
    @Published private(set) var itemsByUser: [String: [String: Date]] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String: Date]].self, from: data) {
            itemsByUser = decoded
        }
        cleanup()
    }

    private var currentUserKey: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? "anonymous"
        #else
        return "anonymous"
        #endif
    }

    func isSnoozed(_ id: String) -> Bool {
        cleanup()
        let uid = currentUserKey
        guard let expiry = itemsByUser[uid]?[id] else { return false }
        return expiry > Date()
    }

    func snooze(id: String, until expiry: Date) {
        var map = itemsByUser[currentUserKey] ?? [:]
        map[id] = expiry
        itemsByUser[currentUserKey] = map
        persist()
    }

    private func cleanup() {
        let now = Date()
        var changed = false
        for (uid, dict) in itemsByUser {
            let filtered = dict.filter { $0.value > now }
            if filtered.count != dict.count { itemsByUser[uid] = filtered; changed = true }
        }
        if changed { persist() }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(itemsByUser) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

