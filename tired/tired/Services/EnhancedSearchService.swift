import Foundation
import FirebaseFirestore
import Combine

/// 增強型全局搜尋服務
@MainActor
final class EnhancedSearchService: ObservableObject {
    static let shared = EnhancedSearchService()
    
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var isSearching = false
    
    private let db = Firestore.firestore()
    private let maxHistoryItems = 20
    private let userDefaultsKey = "com.tired.searchHistory"
    
    private init() {
        loadSearchHistory()
    }
    
    // MARK: - Search
    
    func search(
        query: String,
        types: [SearchType],
        tenantId: String? = nil,
        limit: Int = 50
    ) async throws -> SearchResults {
        isSearching = true
        defer { isSearching = false }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else {
            return SearchResults(query: query, posts: [], users: [], broadcasts: [], events: [], polls: [])
        }
        
        // 添加到搜尋歷史
        addToHistory(query: trimmedQuery, types: types)
        
        // 並發搜尋所有類型
        async let postsTask = types.contains(.post) ? searchPosts(query: trimmedQuery, tenantId: tenantId, limit: limit) : []
        async let usersTask = types.contains(.user) ? searchUsers(query: trimmedQuery, limit: limit) : []
        async let broadcastsTask = types.contains(.broadcast) ? searchBroadcasts(query: trimmedQuery, tenantId: tenantId, limit: limit) : []
        async let eventsTask = types.contains(.event) ? searchEvents(query: trimmedQuery, tenantId: tenantId, limit: limit) : []
        async let pollsTask = types.contains(.poll) ? searchPolls(query: trimmedQuery, tenantId: tenantId, limit: limit) : []
        
        let (posts, users, broadcasts, events, polls) = await (
            postsTask,
            usersTask,
            broadcastsTask,
            eventsTask,
            pollsTask
        )
        
        return SearchResults(
            query: query,
            posts: posts,
            users: users,
            broadcasts: broadcasts,
            events: events,
            polls: polls
        )
    }
    
    // MARK: - Search by Type
    
    private func searchPosts(query: String, tenantId: String?, limit: Int) async -> [SearchResultPost] {
        do {
            var queryRef = db.collection("posts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            if let tenantId = tenantId {
                queryRef = db.collection("posts")
                    .whereField("tenantId", isEqualTo: tenantId)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
            }
            
            let snapshot = try await queryRef.getDocuments()
            
            return snapshot.documents.compactMap { doc -> SearchResultPost? in
                let data = doc.data()
                guard let content = data["content"] as? String,
                      let authorId = data["authorId"] as? String,
                      let authorName = data["authorName"] as? String,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                      content.lowercased().contains(query) else {
                    return nil
                }
                
                return SearchResultPost(
                    id: doc.documentID,
                    content: content,
                    authorId: authorId,
                    authorName: authorName,
                    authorPhotoURL: data["authorPhotoURL"] as? String,
                    imageURLs: data["imageURLs"] as? [String] ?? [],
                    likeCount: data["likeCount"] as? Int ?? 0,
                    commentCount: data["commentCount"] as? Int ?? 0,
                    createdAt: createdAt,
                    highlightedContent: highlightMatches(in: content, query: query)
                )
            }
        } catch {
            print("❌ 搜尋貼文失敗: \(error)")
            return []
        }
    }
    
    private func searchUsers(query: String, limit: Int) async -> [SearchResultUser] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "displayName")
                .limit(to: limit * 2) // 獲取更多然後篩選
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> SearchResultUser? in
                let data = doc.data()
                guard let displayName = data["displayName"] as? String,
                      displayName.lowercased().contains(query) else {
                    return nil
                }
                
                return SearchResultUser(
                    id: doc.documentID,
                    displayName: displayName,
                    bio: data["bio"] as? String,
                    photoURL: data["photoURL"] as? String,
                    verified: data["verified"] as? Bool ?? false,
                    highlightedName: highlightMatches(in: displayName, query: query)
                )
            }.prefix(limit).map { $0 }
        } catch {
            print("❌ 搜尋用戶失敗: \(error)")
            return []
        }
    }
    
    private func searchBroadcasts(query: String, tenantId: String?, limit: Int) async -> [SearchResultBroadcast] {
        do {
            var queryRef = db.collection("broadcasts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            if let tenantId = tenantId {
                queryRef = db.collection("broadcasts")
                    .whereField("tenantId", isEqualTo: tenantId)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
            }
            
            let snapshot = try await queryRef.getDocuments()
            
            return snapshot.documents.compactMap { doc -> SearchResultBroadcast? in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let body = data["body"] as? String,
                      let authorName = data["authorName"] as? String,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                      (title.lowercased().contains(query) || body.lowercased().contains(query)) else {
                    return nil
                }
                
                return SearchResultBroadcast(
                    id: doc.documentID,
                    title: title,
                    body: body,
                    authorName: authorName,
                    requiresAck: data["requiresAck"] as? Bool ?? false,
                    priority: data["priority"] as? String,
                    createdAt: createdAt,
                    highlightedTitle: highlightMatches(in: title, query: query),
                    highlightedBody: highlightMatches(in: body, query: query)
                )
            }
        } catch {
            print("❌ 搜尋公告失敗: \(error)")
            return []
        }
    }
    
    private func searchEvents(query: String, tenantId: String?, limit: Int) async -> [SearchResultEvent] {
        do {
            var queryRef = db.collection("events")
                .order(by: "startTime", descending: false)
                .limit(to: limit)
            
            if let tenantId = tenantId {
                queryRef = db.collection("events")
                    .whereField("tenantId", isEqualTo: tenantId)
                    .order(by: "startTime", descending: false)
                    .limit(to: limit)
            }
            
            let snapshot = try await queryRef.getDocuments()
            
            return snapshot.documents.compactMap { doc -> SearchResultEvent? in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                      title.lowercased().contains(query) else {
                    return nil
                }
                
                return SearchResultEvent(
                    id: doc.documentID,
                    title: title,
                    description: data["description"] as? String,
                    location: data["location"] as? String,
                    startTime: startTime,
                    endTime: (data["endTime"] as? Timestamp)?.dateValue(),
                    registeredCount: data["registeredCount"] as? Int ?? 0,
                    capacity: data["capacity"] as? Int,
                    highlightedTitle: highlightMatches(in: title, query: query)
                )
            }
        } catch {
            print("❌ 搜尋活動失敗: \(error)")
            return []
        }
    }
    
    private func searchPolls(query: String, tenantId: String?, limit: Int) async -> [SearchResultPoll] {
        do {
            var queryRef = db.collection("polls")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            if let tenantId = tenantId {
                queryRef = db.collection("polls")
                    .whereField("tenantId", isEqualTo: tenantId)
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
            }
            
            let snapshot = try await queryRef.getDocuments()
            
            return snapshot.documents.compactMap { doc -> SearchResultPoll? in
                let data = doc.data()
                guard let question = data["question"] as? String,
                      let options = data["options"] as? [String],
                      question.lowercased().contains(query) else {
                    return nil
                }
                
                return SearchResultPoll(
                    id: doc.documentID,
                    question: question,
                    options: options,
                    totalVotes: data["totalVotes"] as? Int ?? 0,
                    deadline: (data["deadline"] as? Timestamp)?.dateValue(),
                    highlightedQuestion: highlightMatches(in: question, query: query)
                )
            }
        } catch {
            print("❌ 搜尋投票失敗: \(error)")
            return []
        }
    }
    
    // MARK: - Search Suggestions
    
    func getSuggestions(for query: String, types: [SearchType]) async -> [SearchSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard trimmedQuery.count >= 2 else {
            return []
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // 從搜尋歷史生成建議
        let historySuggestions = searchHistory
            .filter { $0.query.lowercased().contains(trimmedQuery) }
            .prefix(3)
            .map { SearchSuggestion(text: $0.query, type: .history) }
        
        suggestions.append(contentsOf: historySuggestions)
        
        // TODO: 可以從後端獲取熱門搜尋、相關標籤等
        
        return suggestions
    }
    
    // MARK: - Search History
    
    private func addToHistory(query: String, types: [SearchType]) {
        let item = SearchHistoryItem(
            query: query,
            types: types,
            timestamp: Date()
        )
        
        // 移除重複項
        searchHistory.removeAll { $0.query == query }
        
        // 添加到開頭
        searchHistory.insert(item, at: 0)
        
        // 限制數量
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    func removeHistoryItem(_ item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            return
        }
        
        searchHistory = decoded
    }
    
    private func saveSearchHistory() {
        if let encoded = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Utility
    
    private func highlightMatches(in text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lowercased = text.lowercased()
        let queryLower = query.lowercased()
        
        var searchRange = lowercased.startIndex..<lowercased.endIndex
        
        while let range = lowercased.range(of: queryLower, range: searchRange) {
            let attributedRange = AttributedString.Index(range.lowerBound, within: attributed)!..<AttributedString.Index(range.upperBound, within: attributed)!
            attributed[attributedRange].foregroundColor = .orange
            attributed[attributedRange].font = .boldSystemFont(ofSize: 16)
            
            searchRange = range.upperBound..<lowercased.endIndex
        }
        
        return attributed
    }
}

// MARK: - Models

enum SearchType: String, Codable {
    case post = "貼文"
    case user = "用戶"
    case broadcast = "公告"
    case event = "活動"
    case poll = "投票"
}

struct SearchResults {
    let query: String
    let posts: [SearchResultPost]
    let users: [SearchResultUser]
    let broadcasts: [SearchResultBroadcast]
    let events: [SearchResultEvent]
    let polls: [SearchResultPoll]
    
    var isEmpty: Bool {
        posts.isEmpty && users.isEmpty && broadcasts.isEmpty && events.isEmpty && polls.isEmpty
    }
    
    var totalCount: Int {
        posts.count + users.count + broadcasts.count + events.count + polls.count
    }
}

struct SearchResultPost: Identifiable {
    let id: String
    let content: String
    let authorId: String
    let authorName: String
    let authorPhotoURL: String?
    let imageURLs: [String]
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    let highlightedContent: AttributedString
}

struct SearchResultUser: Identifiable {
    let id: String
    let displayName: String
    let bio: String?
    let photoURL: String?
    let verified: Bool
    let highlightedName: AttributedString
}

struct SearchResultBroadcast: Identifiable {
    let id: String
    let title: String
    let body: String
    let authorName: String
    let requiresAck: Bool
    let priority: String?
    let createdAt: Date
    let highlightedTitle: AttributedString
    let highlightedBody: AttributedString
}

struct SearchResultEvent: Identifiable {
    let id: String
    let title: String
    let description: String?
    let location: String?
    let startTime: Date
    let endTime: Date?
    let registeredCount: Int
    let capacity: Int?
    let highlightedTitle: AttributedString
}

struct SearchResultPoll: Identifiable {
    let id: String
    let question: String
    let options: [String]
    let totalVotes: Int
    let deadline: Date?
    let highlightedQuestion: AttributedString
}

struct SearchHistoryItem: Identifiable, Codable {
    let id: String
    let query: String
    let types: [SearchType]
    let timestamp: Date
    
    init(query: String, types: [SearchType], timestamp: Date) {
        self.id = UUID().uuidString
        self.query = query
        self.types = types
        self.timestamp = timestamp
    }
}

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case history
        case trending
        case related
    }
}

