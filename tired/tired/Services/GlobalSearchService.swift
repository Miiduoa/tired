import Foundation
import FirebaseFirestore

/// 全局搜尋服務
@MainActor
final class GlobalSearchService {
    static let shared = GlobalSearchService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Search
    
    /// 全局搜尋
    func search(query: String, tenantId: String?, filters: SearchFilters = SearchFilters()) async throws -> SearchResults {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else {
            return SearchResults(posts: [], users: [], broadcasts: [], events: [])
        }
        
        async let posts = filters.includePosts ? searchPosts(query: trimmedQuery, tenantId: tenantId) : []
        async let users = filters.includeUsers ? searchUsers(query: trimmedQuery, tenantId: tenantId) : []
        async let broadcasts = filters.includeBroadcasts ? searchBroadcasts(query: trimmedQuery, tenantId: tenantId) : []
        async let events = filters.includeEvents ? searchEvents(query: trimmedQuery, tenantId: tenantId) : []
        
        return try await SearchResults(
            posts: posts,
            users: users,
            broadcasts: broadcasts,
            events: events
        )
    }
    
    // MARK: - Search by Type
    
    /// 搜尋文章
    private func searchPosts(query: String, tenantId: String?) async throws -> [PostSearchResult] {
        var dbQuery: Query = db.collection("posts")
        
        if let tenantId = tenantId {
            dbQuery = dbQuery.whereField("tenantId", isEqualTo: tenantId)
        }
        
        let snapshot = try await dbQuery
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        // 客戶端過濾（因為 Firestore 不支持全文搜尋）
        let posts = snapshot.documents.compactMap { doc -> PostSearchResult? in
            guard let data = doc.data() as? [String: Any],
                  let content = data["content"] as? String,
                  let authorName = data["authorName"] as? String else {
                return nil
            }
            
            // 檢查是否匹配搜尋關鍵字
            let contentLower = content.lowercased()
            let authorLower = authorName.lowercased()
            
            guard contentLower.contains(query) || authorLower.contains(query) else {
                return nil
            }
            
            let id = doc.documentID
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return PostSearchResult(
                id: id,
                summary: String(content.prefix(100)),
                content: content,
                authorName: authorName,
                createdAt: createdAt,
                highlights: findHighlights(in: content, query: query)
            )
        }
        
        return posts
    }
    
    /// 搜尋用戶
    private func searchUsers(query: String, tenantId: String?) async throws -> [UserSearchResult] {
        let snapshot = try await db.collection("users")
            .limit(to: 20)
            .getDocuments()
        
        // 客戶端過濾
        let users = snapshot.documents.compactMap { doc -> UserSearchResult? in
            guard let data = doc.data() as? [String: Any],
                  let displayName = data["displayName"] as? String else {
                return nil
            }
            
            // 檢查是否匹配
            let displayNameLower = displayName.lowercased()
            let email = data["email"] as? String ?? ""
            let emailLower = email.lowercased()
            
            guard displayNameLower.contains(query) || emailLower.contains(query) else {
                return nil
            }
            
            let id = doc.documentID
            let avatarUrl = data["photoURL"] as? String
            
            return UserSearchResult(
                id: id,
                displayName: displayName,
                email: email,
                avatarUrl: avatarUrl
            )
        }
        
        return users
    }
    
    /// 搜尋公告
    private func searchBroadcasts(query: String, tenantId: String?) async throws -> [BroadcastSearchResult] {
        var dbQuery: Query = db.collection("broadcasts")
        
        if let tenantId = tenantId {
            dbQuery = dbQuery.whereField("tenantId", isEqualTo: tenantId)
        }
        
        let snapshot = try await dbQuery
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .getDocuments()
        
        // 客戶端過濾
        let broadcasts = snapshot.documents.compactMap { doc -> BroadcastSearchResult? in
            guard let data = doc.data() as? [String: Any],
                  let title = data["title"] as? String,
                  let body = data["body"] as? String else {
                return nil
            }
            
            // 檢查是否匹配
            let titleLower = title.lowercased()
            let bodyLower = body.lowercased()
            
            guard titleLower.contains(query) || bodyLower.contains(query) else {
                return nil
            }
            
            let id = doc.documentID
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            return BroadcastSearchResult(
                id: id,
                title: title,
                body: body,
                createdAt: createdAt,
                highlights: findHighlights(in: title + " " + body, query: query)
            )
        }
        
        return broadcasts
    }
    
    /// 搜尋活動
    private func searchEvents(query: String, tenantId: String?) async throws -> [EventSearchResult] {
        var dbQuery: Query = db.collection("events")
        
        if let tenantId = tenantId {
            dbQuery = dbQuery.whereField("tenantId", isEqualTo: tenantId)
        }
        
        let snapshot = try await dbQuery
            .order(by: "startTime", descending: false)
            .limit(to: 30)
            .getDocuments()
        
        // 客戶端過濾
        let events = snapshot.documents.compactMap { doc -> EventSearchResult? in
            guard let data = doc.data() as? [String: Any],
                  let title = data["title"] as? String,
                  let description = data["description"] as? String else {
                return nil
            }
            
            // 檢查是否匹配
            let titleLower = title.lowercased()
            let descriptionLower = description.lowercased()
            
            guard titleLower.contains(query) || descriptionLower.contains(query) else {
                return nil
            }
            
            let id = doc.documentID
            let startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date()
            let location = data["location"] as? String
            
            return EventSearchResult(
                id: id,
                title: title,
                description: description,
                startTime: startTime,
                location: location
            )
        }
        
        return events
    }
    
    // MARK: - Recent Searches
    
    private var recentSearches: [String] = []
    private let maxRecentSearches = 10
    
    /// 保存搜尋記錄
    func saveRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 移除重複
        recentSearches.removeAll { $0 == trimmed }
        
        // 添加到最前面
        recentSearches.insert(trimmed, at: 0)
        
        // 限制數量
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
    
    /// 獲取最近搜尋
    func getRecentSearches() -> [String] {
        if recentSearches.isEmpty {
            recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
        }
        return recentSearches
    }
    
    /// 清除最近搜尋
    func clearRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }
    
    // MARK: - Helpers
    
    private func findHighlights(in text: String, query: String) -> [String] {
        let words = query.split(separator: " ")
        var highlights: [String] = []
        
        for word in words {
            let wordString = String(word).lowercased()
            let textLower = text.lowercased()
            
            if let range = textLower.range(of: wordString) {
                let start = max(textLower.distance(from: textLower.startIndex, to: range.lowerBound) - 20, 0)
                let end = min(textLower.distance(from: textLower.startIndex, to: range.upperBound) + 20, text.count)
                
                let startIndex = text.index(text.startIndex, offsetBy: start)
                let endIndex = text.index(text.startIndex, offsetBy: end)
                
                let highlight = String(text[startIndex..<endIndex])
                highlights.append("...\(highlight)...")
            }
        }
        
        return highlights
    }
    
    // MARK: - Sorting & Filtering
    
    /// 排序搜尋結果
    func sortResults(_ results: SearchResults, by sortOption: SortOption) -> SearchResults {
        var sorted = results
        
        switch sortOption {
        case .relevance:
            // 已經按相關性排序（由搜尋匹配度決定）
            break
        case .dateNewest:
            sorted = SearchResults(
                posts: results.posts.sorted { $0.createdAt > $1.createdAt },
                users: results.users,
                broadcasts: results.broadcasts.sorted { $0.createdAt > $1.createdAt },
                events: results.events.sorted { $0.startTime > $1.startTime }
            )
        case .dateOldest:
            sorted = SearchResults(
                posts: results.posts.sorted { $0.createdAt < $1.createdAt },
                users: results.users,
                broadcasts: results.broadcasts.sorted { $0.createdAt < $1.createdAt },
                events: results.events.sorted { $0.startTime < $1.startTime }
            )
        }
        
        return sorted
    }
    
    /// 過濾搜尋結果
    func filterResults(_ results: SearchResults, dateRange: DateRange? = nil) -> SearchResults {
        var filtered = results
        
        if let dateRange = dateRange {
            filtered = SearchResults(
                posts: results.posts.filter { isInDateRange($0.createdAt, range: dateRange) },
                users: results.users,
                broadcasts: results.broadcasts.filter { isInDateRange($0.createdAt, range: dateRange) },
                events: results.events.filter { isInDateRange($0.startTime, range: dateRange) }
            )
        }
        
        return filtered
    }
    
    private func isInDateRange(_ date: Date, range: DateRange) -> Bool {
        return date >= range.start && date <= range.end
    }
}

// MARK: - Models

enum SortOption {
    case relevance
    case dateNewest
    case dateOldest
}

struct DateRange {
    let start: Date
    let end: Date
}

struct SearchFilters {
    var includePosts: Bool = true
    var includeUsers: Bool = true
    var includeBroadcasts: Bool = true
    var includeEvents: Bool = true
    var sortBy: SortOption = .relevance
    var dateRange: DateRange? = nil
}

struct SearchResults {
    let posts: [PostSearchResult]
    let users: [UserSearchResult]
    let broadcasts: [BroadcastSearchResult]
    let events: [EventSearchResult]
    
    var isEmpty: Bool {
        posts.isEmpty && users.isEmpty && broadcasts.isEmpty && events.isEmpty
    }
    
    var totalCount: Int {
        posts.count + users.count + broadcasts.count + events.count
    }
}

struct PostSearchResult: Identifiable {
    let id: String
    let summary: String
    let content: String
    let authorName: String
    let createdAt: Date
    let highlights: [String]
}

struct UserSearchResult: Identifiable {
    let id: String
    let displayName: String
    let email: String
    let avatarUrl: String?
}

struct BroadcastSearchResult: Identifiable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let highlights: [String]
}

struct EventSearchResult: Identifiable {
    let id: String
    let title: String
    let description: String
    let startTime: Date
    let location: String?
}

