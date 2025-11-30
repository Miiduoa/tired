import Foundation

/// A unified struct to represent a search result.
struct GlobalSearchResult: Codable, Hashable, Identifiable {
    var id: String { objectID }
    let objectID: String
    let title: String
    let snippet: String? // A highlighted snippet or secondary info
    let type: SearchResultType
    
    enum SearchResultType: String, Codable {
        case organization
        case task
        case event
        case post
        case user // 新增 user 類型
    }
    
    // Custom coding keys to map from Algolia's response if needed
    enum CodingKeys: String, CodingKey {
        case objectID
        case title
        case snippet
        case type
    }
}
