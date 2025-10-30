import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class AckStore: ObservableObject {
    static let shared = AckStore()

    // userId -> Set(messageId)
    @Published private(set) var ackedByUser: [String: Set<String>]
    private let storageKey = "AckStore.ackedByUser"
    private let legacyKey = "AckStore.ackedIds" // for migration

    private init() {
        // Load new structure
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            ackedByUser = decoded.mapValues { Set($0) }
        } else if let legacy = UserDefaults.standard.array(forKey: legacyKey) as? [String] {
            // Migrate legacy flat set into anonymous bucket
            ackedByUser = [Self.anonymousKey: Set(legacy)]
            persist()
            UserDefaults.standard.removeObject(forKey: legacyKey)
        } else {
            ackedByUser = [:]
        }
    }

    func isAcked(_ id: String) -> Bool {
        let uid = Self.currentUserKey
        return ackedByUser[uid]?.contains(id) ?? false
    }

    func ack(_ id: String) {
        let uid = Self.currentUserKey
        var set = ackedByUser[uid] ?? []
        guard !set.contains(id) else { return }
        set.insert(id)
        ackedByUser[uid] = set
        persist()
    }

    private func persist() {
        let encodable = ackedByUser.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static let anonymousKey = "anonymous"

    private static var currentUserKey: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? anonymousKey
        #else
        return anonymousKey
        #endif
    }
}
