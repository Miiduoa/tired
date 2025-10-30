import Foundation
import Combine

@MainActor
final class ReadStateStore: ObservableObject {
    static let shared = ReadStateStore()
    @Published private(set) var lastOpenedAt: [String: Date] = [:] // conversationId -> date
    private let storageKey = "ReadState.lastOpenedAt"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastOpenedAt = decoded
        }
    }

    func markOpened(conversationId: String, at date: Date = Date()) {
        lastOpenedAt[conversationId] = date
        persist()
    }

    func lastOpened(conversationId: String) -> Date? { lastOpenedAt[conversationId] }

    private func persist() {
        if let data = try? JSONEncoder().encode(lastOpenedAt) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

