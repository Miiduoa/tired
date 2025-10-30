import Foundation

protocol Deduplicable {
    var dedupeKey: String { get }
}

extension Array where Element: Deduplicable {
    func deduped() -> [Element] {
        var seen: [String: Element] = [:]
        for element in self {
            let key = element.dedupeKey
            if seen[key] == nil {
                seen[key] = element
            }
        }
        return Array(seen.values)
    }
}
