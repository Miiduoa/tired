import Foundation
import CoreLocation

enum ClockAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case outsideGeofence
    case duplicateRecord
    case amendNotAllowed
}

/// 打卡 API 服務
struct ClockAPI {
    
    // MARK: - 打卡記錄
    
    /// 提交打卡記錄
    /// - Parameters:
    ///   - uid: 用戶 ID
    ///   - site: 打卡地點
    ///   - idempotencyKey: 冪等性鍵
    ///   - location: GPS 位置
    ///   - timestamp: 打卡時間
    /// - Returns: 記錄 ID
    static func clockIn(
        uid: String,
        site: String,
        idempotencyKey: String,
        location: CLLocationCoordinate2D? = nil,
        timestamp: Date = Date()
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/clock/records") else {
            // 離線模式：生成本地 ID
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        
        var payload: [String: Any] = [
            "uid": uid,
            "site": site,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        
        if let location = location {
            payload["location"] = [
                "lat": location.latitude,
                "lng": location.longitude
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClockAPIError.requestFailed("Invalid response")
        }
        
        switch http.statusCode {
        case 200...299:
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = obj["id"] as? String {
                return id
            }
            return "remote-\(UUID().uuidString)"
        case 400:
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                if error.code == "DUPLICATE_RECORD" {
                    throw ClockAPIError.duplicateRecord
                } else if error.code == "OUTSIDE_GEOFENCE" {
                    throw ClockAPIError.outsideGeofence
                }
            }
            throw ClockAPIError.requestFailed("Bad request")
        default:
            throw ClockAPIError.requestFailed("HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - 修改打卡記錄
    
    /// 申請修改打卡記錄
    /// - Parameters:
    ///   - recordId: 記錄 ID
    ///   - newTime: 新的打卡時間
    ///   - reason: 修改原因
    ///   - evidence: 證據（可選）
    static func requestAmendment(
        recordId: String,
        newTime: Date,
        reason: String,
        evidence: [String]? = nil
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/clock/records/\(recordId)/amend")
        else {
            try await Task.sleep(nanoseconds: 300_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "newTime": ISO8601DateFormatter().string(from: newTime),
            "reason": reason
        ]
        
        if let evidence = evidence {
            payload["evidence"] = evidence
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClockAPIError.requestFailed("Failed to request amendment")
        }
    }
    
    // MARK: - 審核修改申請
    
    /// 審核修改申請
    /// - Parameters:
    ///   - amendmentId: 修改申請 ID
    ///   - approved: 是否批准
    ///   - reviewerId: 審核者 ID
    ///   - comment: 審核意見
    static func reviewAmendment(
        amendmentId: String,
        approved: Bool,
        reviewerId: String,
        comment: String? = nil
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/clock/amendments/\(amendmentId)/review")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "approved": approved,
            "reviewerId": reviewerId
        ]
        
        if let comment = comment {
            payload["comment"] = comment
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClockAPIError.requestFailed("Failed to review amendment")
        }
    }
    
    // MARK: - 獲取打卡記錄
    
    /// 獲取用戶的打卡記錄
    /// - Parameters:
    ///   - uid: 用戶 ID
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    /// - Returns: 打卡記錄列表
    static func fetchRecords(
        uid: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [ClockRecordItem] {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"] else {
            // 離線模式：返回模擬數據
            return ClockRecordItem.mockRecords()
        }
        
        var components = URLComponents(string: "\(endpoint)/v1/clock/records")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "uid", value: uid)]
        
        if let startDate = startDate {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: startDate)))
        }
        
        if let endDate = endDate {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: endDate)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw ClockAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClockAPIError.requestFailed("Failed to fetch records")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ClockRecordItem].self, from: data)
    }
    
    // MARK: - 獲取待審核列表
    
    /// 獲取待審核的修改申請
    static func fetchPendingAmendments(reviewerId: String) async throws -> [AmendmentRequest] {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/clock/amendments/pending?reviewerId=\(reviewerId)")
        else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClockAPIError.requestFailed("Failed to fetch pending amendments")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AmendmentRequest].self, from: data)
    }
}

// MARK: - 輔助數據結構

private struct ErrorResponse: Codable {
    let code: String
    let message: String
}

/// 修改申請數據模型
struct AmendmentRequest: Codable, Identifiable {
    let id: String
    let recordId: String
    let userId: String
    let userName: String
    let originalTime: Date
    let newTime: Date
    let reason: String
    let evidence: [String]?
    let status: Status
    let createdAt: Date
    
    enum Status: String, Codable {
        case pending
        case approved
        case rejected
    }
}

// MARK: - Mock 數據擴展

extension ClockRecordItem {
    static func mockRecords() -> [ClockRecordItem] {
        return [
            ClockRecordItem(id: "1", site: "總部大樓", time: Date(), status: .ok),
            ClockRecordItem(id: "2", site: "研發中心", time: Date().addingTimeInterval(-86400), status: .ok),
            ClockRecordItem(id: "3", site: "總部大樓", time: Date().addingTimeInterval(-172800), status: .exception)
        ]
    }
}
