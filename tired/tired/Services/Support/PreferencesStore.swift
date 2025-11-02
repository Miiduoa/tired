import Foundation

final class FeedFilterStore {
    private func key(for userId: String) -> String { "FeedFilter." + userId }

    func load(userId: String) -> FeedFilter {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: key(for: userId)),
              let filter = try? JSONDecoder().decode(FeedFilter.self, from: data) else {
            return FeedFilter()
        }
        return filter
    }

    func save(_ filter: FeedFilter, for userId: String) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(filter) {
            defaults.set(data, forKey: key(for: userId))
        }
    }
}

