import Foundation

enum BroadcastAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case notAuthorized
    case broadcastNotFound
}

/// 公告 API 服務
struct BroadcastAPI {
    
    // MARK: - 創建公告
    
    /// 創建新公告
    /// - Parameters:
    ///   - title: 標題
    ///   - body: 內容
    ///   - requiresAck: 是否需要回條
    ///   - deadline: 截止日期
    ///   - targetGroup: 目標組織
    ///   - authorId: 作者 ID
    /// - Returns: 公告 ID
    static func create(
        title: String,
        body: String,
        requiresAck: Bool,
        deadline: Date?,
        targetGroup: String,
        authorId: String
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/broadcasts")
        else {
            // 離線模式
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "title": title,
            "body": body,
            "requiresAck": requiresAck,
            "targetGroup": targetGroup,
            "authorId": authorId
        ]
        
        if let deadline = deadline {
            payload["deadline"] = ISO8601DateFormatter().string(from: deadline)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to create broadcast")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = obj["id"] as? String {
            return id
        }
        
        return "remote-\(UUID().uuidString)"
    }
    
    // MARK: - 更新公告
    
    /// 更新公告
    /// - Parameters:
    ///   - broadcastId: 公告 ID
    ///   - title: 新標題
    ///   - body: 新內容
    ///   - deadline: 新截止日期
    static func update(
        broadcastId: String,
        title: String?,
        body: String?,
        deadline: Date?
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/broadcasts/\(broadcastId)")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [:]
        
        if let title = title {
            payload["title"] = title
        }
        
        if let body = body {
            payload["body"] = body
        }
        
        if let deadline = deadline {
            payload["deadline"] = ISO8601DateFormatter().string(from: deadline)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to update broadcast")
        }
    }
    
    // MARK: - 刪除公告
    
    /// 刪除公告
    static func delete(broadcastId: String, authorId: String) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/broadcasts/\(broadcastId)")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(authorId, forHTTPHeaderField: "X-Author-Id")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BroadcastAPIError.requestFailed("Invalid response")
        }
        if httpResponse.statusCode == 403 {
            throw BroadcastAPIError.notAuthorized
        } else if httpResponse.statusCode == 404 {
            throw BroadcastAPIError.broadcastNotFound
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to delete broadcast")
        }
    }
    
    // MARK: - 回條確認
    
    /// 用戶確認已讀公告並回條
    static func acknowledge(
        broadcastId: String,
        uid: String,
        idempotencyKey: String? = nil
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/broadcasts/\(broadcastId)/ack")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "uid": uid,
            "idempotencyKey": idempotencyKey ?? UUID().uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to acknowledge broadcast")
        }
    }

    // Back-compat wrapper for older call sites
    static func ack(broadcastId: String, uid: String, idempotencyKey: String? = nil) async throws {
        try await acknowledge(broadcastId: broadcastId, uid: uid, idempotencyKey: idempotencyKey)
    }
    
    // MARK: - 獲取公告列表
    
    /// 獲取組織的公告列表
    static func fetchList(
        groupId: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [BroadcastListItem] {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            // 離線模式
            return BroadcastListItem.mockData()
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/broadcasts")!
        components.queryItems = [
            URLQueryItem(name: "groupId", value: groupId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        guard let url = components.url else {
            throw BroadcastAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to fetch broadcasts")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([BroadcastListItem].self, from: data)
    }
    
    // MARK: - 獲取回條統計
    
    /// 獲取公告的回條統計
    static func fetchAckStats(broadcastId: String) async throws -> AckStats {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/broadcasts/\(broadcastId)/ack-stats")
        else {
            // 離線模式
            return AckStats(total: 100, acked: 75, pending: 25)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BroadcastAPIError.requestFailed("Failed to fetch ack stats")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AckStats.self, from: data)
    }
}

// MARK: - 輔助數據結構

struct AckStats: Codable {
    let total: Int
    let acked: Int
    let pending: Int
    
    var ackRate: Double {
        guard total > 0 else { return 0 }
        return Double(acked) / Double(total)
    }
}

// MARK: - Mock 數據

extension BroadcastListItem {
    static func mockData() -> [BroadcastListItem] {
        return [
            BroadcastListItem(
                id: "1",
                title: "期中考試通知",
                body: "下週一至週三進行期中考試，請同學準時到場",
                deadline: Date().addingTimeInterval(604800),
                requiresAck: true,
                acked: false,
                eventId: nil
            ),
            BroadcastListItem(
                id: "2",
                title: "校慶活動報名",
                body: "校慶將於下月舉行，歡迎同學踴躍報名參加各項活動",
                deadline: Date().addingTimeInterval(2592000),
                requiresAck: false,
                acked: false,
                eventId: "event-1"
            )
        ]
    }
}
