import Foundation

enum SearchServiceError: Error {
    case invalidURL
    case searchFailed(String)
}

/// 全局搜索服務
class SearchService {
    
    static let shared = SearchService()
    
    private init() {}
    
    // MARK: - 全局搜索
    
    /// 執行全局搜索
    /// - Parameters:
    ///   - query: 搜索關鍵詞
    ///   - scope: 搜索範圍
    ///   - groupId: 組織 ID（可選，限定搜索範圍）
    ///   - limit: 每類結果的最大數量
    /// - Returns: 搜索結果
    func search(
        query: String,
        scope: SearchScope = .all,
        groupId: String? = nil,
        limit: Int = 10
    ) async throws -> SearchResults {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return SearchResults(posts: [], broadcasts: [], users: [], events: [])
        }
        
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            // 離線模式：返回 Mock 搜索結果
            let mockProvider = await MockDataProvider.shared
            let posts = await scope == .posts || scope == .all ? mockProvider.mockPosts() : []
            let broadcasts = await (scope == .broadcasts || scope == .all) ? mockProvider.mockBroadcasts().map { broadcast in
                BroadcastSearchResult(
                    id: broadcast.id,
                    title: broadcast.title,
                    body: broadcast.body,
                    deadline: broadcast.deadline,
                    highlights: []
                )
            } : []
            let users = await scope == .users || scope == .all ? mockProvider.mockUsers() : []
            let events = await (scope == .events || scope == .all) ? mockProvider.mockEvents().map { event in
                EventSearchResult(
                    id: event.id,
                    title: event.title,
                    description: event.description ?? "",
                    startTime: event.startTime,
                    location: event.location ?? "",
                    highlights: []
                )
            } : []
            
            // 簡單的關鍵詞過濾
            let queryLower = trimmedQuery.lowercased()
            return SearchResults(
                posts: posts.filter { $0.summary.lowercased().contains(queryLower) || $0.content.lowercased().contains(queryLower) },
                broadcasts: broadcasts.filter { $0.title.lowercased().contains(queryLower) || $0.body.lowercased().contains(queryLower) },
                users: users.filter { $0.displayName.lowercased().contains(queryLower) },
                events: events.filter { $0.title.lowercased().contains(queryLower) || $0.description.lowercased().contains(queryLower) }
            )
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/search")!
        var queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let groupId = groupId {
            queryItems.append(URLQueryItem(name: "groupId", value: groupId))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SearchServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SearchServiceError.searchFailed("Search request failed")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SearchResults.self, from: data)
    }
    
    // MARK: - 搜索建議
    
    /// 獲取搜索建議（自動完成）
    /// - Parameters:
    ///   - query: 部分搜索詞
    ///   - limit: 建議數量
    /// - Returns: 建議列表
    func suggestions(
        for query: String,
        limit: Int = 5
    ) async throws -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedQuery.count >= 2 else {
            return []
        }
        
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/search/suggestions?q=\(trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)")
        else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let suggestions = obj["suggestions"] as? [String] {
            return suggestions
        }
        
        return []
    }
    
    // MARK: - 搜索歷史
    
    private let historyKey = "search_history"
    private let maxHistoryCount = 20
    
    /// 保存搜索歷史
    func saveToHistory(_ query: String) {
        var history = getHistory()
        
        // 移除重複項
        history.removeAll { $0 == query }
        
        // 插入到最前面
        history.insert(query, at: 0)
        
        // 限制數量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        UserDefaults.standard.set(history, forKey: historyKey)
    }
    
    /// 獲取搜索歷史
    func getHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
    
    /// 清空搜索歷史
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    /// 刪除單條歷史記錄
    func removeFromHistory(_ query: String) {
        var history = getHistory()
        history.removeAll { $0 == query }
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}

// MARK: - 數據結構

enum SearchScope: String, Codable {
    case all = "all"
    case posts = "posts"
    case broadcasts = "broadcasts"
    case users = "users"
    case events = "events"
}

struct SearchResults: Codable {
    let posts: [PostSearchResult]
    let broadcasts: [BroadcastSearchResult]
    let users: [UserSearchResult]
    let events: [EventSearchResult]
    
    var isEmpty: Bool {
        return posts.isEmpty && broadcasts.isEmpty && users.isEmpty && events.isEmpty
    }
    
    var totalCount: Int {
        return posts.count + broadcasts.count + users.count + events.count
    }
}

struct PostSearchResult: Codable, Identifiable {
    let id: String
    let summary: String
    let content: String
    let authorName: String
    let createdAt: Date
    let highlights: [String]
}

struct BroadcastSearchResult: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let deadline: Date?
    let highlights: [String]
}

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let displayName: String
    let email: String?
    let avatarUrl: String?
}

struct EventSearchResult: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let startTime: Date
    let location: String
    let highlights: [String]
}

