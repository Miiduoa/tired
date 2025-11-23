import Foundation
#if canImport(AlgoliaSearchClient)
import AlgoliaSearchClient

/// 用於處理 Algolia 搜尋的服務
class AlgoliaService {
    
    private let client: SearchClient
    private let index: Index

    enum AlgoliaError: Error {
        case missingCredentials
        case invalidResponse
    }

    init?() {
        // --- Algolia 設定 ---
        // 重要：請務必在 Info.plist 中加入 'AlgoliaAppID' 和 'AlgoliaSearchOnlyAPIKey'
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "AlgoliaAppID") as? String,
              let apiKey = Bundle.main.object(forInfoDictionaryKey: "AlgoliaSearchOnlyAPIKey") as? String,
              !appID.isEmpty, !apiKey.isEmpty else {
            print("❌ Algolia Credentials not found in Info.plist. Please add 'AlgoliaAppID' and 'AlgoliaSearchOnlyAPIKey'.")
            return nil
        }
        
        self.client = .init(appID: ApplicationID(rawValue: appID), apiKey: APIKey(rawValue: apiKey))
        self.index = client.index(withName: "organizations") // 確保與你後端設定的 index 名稱一致
    }

    /// 在 Algolia 中搜尋組織
    /// - Parameter query: 搜尋的關鍵字
    /// - Returns: 符合條件的組織 ID 列表
    func search(query: String) async throws -> [String] {
        let result = try await index.search(query: Query(query))
        
        // 從搜尋結果中提取 objectID
        let organizationIDs = try result.hits.map { hit -> String in
            // Algolia 回傳的資料是 JSON，我們只需要 objectID
            return hit.objectID.rawValue
        }
        
        return organizationIDs
    }
}
#else
/// 用於處理 Algolia 搜尋的服務（AlgoliaSearchClient 未安裝時使用）
class AlgoliaService {
    init?() {
        print("⚠️ AlgoliaSearchClient is not installed. Search functionality will be limited.")
        return nil
    }
    
    func search(query: String) async throws -> [String] {
        throw NSError(domain: "AlgoliaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "AlgoliaSearchClient is not installed"])
    }
}
#endif
