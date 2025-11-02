import Foundation

// 用於可去重的元素
protocol Deduplicable {
    var dedupeKey: String { get }
}

// 收件匣類型的比較輔助（若同 key，優先級規則適用）
protocol InboxItemLike {
    var isUrgent: Bool { get }
    var deadline: Date? { get }
}

extension Array where Element: Deduplicable {
    /// 去重規則：
    /// - 以 `dedupeKey` 分組
    /// - 若元素同時也符合 InboxItemLike：
    ///   1) urgent > non-urgent
    ///   2) 同為 urgent 時，deadline 較早者優先
    /// - 其他情況保留第一個出現者
    func deduped() -> [Element] {
        var seen: [String: Element] = [:]
        for element in self {
            let key = element.dedupeKey
            if let existing = seen[key] {
                seen[key] = Self.prefer(new: element, existing: existing)
            } else {
                seen[key] = element
            }
        }
        return Array(seen.values)
    }

    private static func prefer(new: Element, existing: Element) -> Element {
        let ex = (existing as Any) as? InboxItemLike
        let ne = (new as Any) as? InboxItemLike

        if let ex = ex, let ne = ne {
            // 1) urgent 優先
            if ex.isUrgent != ne.isUrgent { return ne.isUrgent ? new : existing }
            // 2) 同為 urgent：deadline 較早者優先（nil 視為無限制，較低優先權）
            if ex.isUrgent && ne.isUrgent {
                switch (ex.deadline, ne.deadline) {
                case let (d1?, d2?):
                    return d2 < d1 ? new : existing
                case (nil, .some):
                    return new
                case (.some, nil):
                    return existing
                default:
                    break
                }
            }
            // 都不 urgent 或無 deadline 差異 => 保留既有
            return existing
        }

        // 只有新值有 InboxItemLike 且 urgent => 取代
        if ex == nil, let ne = ne, ne.isUrgent { return new }
        return existing
    }
}
