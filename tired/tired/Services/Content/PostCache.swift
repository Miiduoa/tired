import Foundation

/// 共用的快取儲存，避免頻繁向 Firestore 重新抓取大量資料。
actor PostCache {
    static let shared = PostCache()
    
    private struct CacheEntry<Value> {
        let value: Value
        let timestamp: Date
        
        func isValid(maxAge: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) <= maxAge
        }
    }
    
    private var personalEntries: [String: CacheEntry<[Post]>] = [:]
    private var feedEntries: [String: CacheEntry<FeedPage>] = [:]
    
    private init() {}
    
    func personalPosts(for userId: String, maxAge: TimeInterval) -> [Post]? {
        guard let entry = personalEntries[userId], entry.isValid(maxAge: maxAge) else {
            return nil
        }
        return entry.value
    }
    
    func setPersonalPosts(_ posts: [Post], for userId: String) {
        personalEntries[userId] = CacheEntry(value: posts, timestamp: Date())
    }
    
    func invalidatePersonalPosts(for userId: String) {
        personalEntries.removeValue(forKey: userId)
    }
    
    func feedPage(for key: String, maxAge: TimeInterval) -> FeedPage? {
        guard let entry = feedEntries[key], entry.isValid(maxAge: maxAge) else {
            return nil
        }
        return entry.value
    }
    
    func setFeedPage(_ page: FeedPage, for key: String) {
        feedEntries[key] = CacheEntry(value: page, timestamp: Date())
    }
    
    func invalidateFeed(for keyPrefix: String? = nil) {
        guard let keyPrefix else {
            feedEntries.removeAll()
            return
        }
        feedEntries = feedEntries.filter { !$0.key.hasPrefix(keyPrefix) }
    }
}
