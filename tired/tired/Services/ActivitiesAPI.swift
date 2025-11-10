import Foundation

enum ActivitiesAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case alreadyVoted
    case ticketInvalid
    case eventFull
}

/// 活動與投票 API 服務
struct ActivitiesAPI {
    
    // MARK: - 創建活動
    
    /// 創建新活動
    /// - Parameters:
    ///   - title: 活動標題
    ///   - description: 活動描述
    ///   - startTime: 開始時間
    ///   - endTime: 結束時間
    ///   - location: 地點
    ///   - capacity: 容量限制（可選）
    ///   - groupId: 組織 ID
    /// - Returns: 活動 ID
    static func createEvent(
        title: String,
        description: String,
        startTime: Date,
        endTime: Date,
        location: String,
        capacity: Int?,
        groupId: String
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/events")
        else {
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "title": title,
            "description": description,
            "startTime": ISO8601DateFormatter().string(from: startTime),
            "endTime": ISO8601DateFormatter().string(from: endTime),
            "location": location,
            "groupId": groupId
        ]
        
        if let capacity = capacity {
            payload["capacity"] = capacity
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ActivitiesAPIError.requestFailed("Failed to create event")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = obj["id"] as? String {
            return id
        }
        
        return "remote-\(UUID().uuidString)"
    }
    
    // MARK: - 報名活動
    
    /// 用戶報名活動
    /// - Parameters:
    ///   - eventId: 活動 ID
    ///   - userId: 用戶 ID
    /// - Returns: 票券資訊
    static func registerForEvent(
        eventId: String,
        userId: String
    ) async throws -> TicketInfo {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/events/\(eventId)/register")
        else {
            // 離線模式
            return TicketInfo(
                ticketId: "local-\(UUID().uuidString)",
                qrCode: UUID().uuidString,
                eventId: eventId,
                userId: userId
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ActivitiesAPIError.requestFailed("Invalid response")
        }
        
        switch http.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(TicketInfo.self, from: data)
        case 409:
            throw ActivitiesAPIError.eventFull
        default:
            throw ActivitiesAPIError.requestFailed("HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - 掃描簽到
    
    /// 掃描票券簽到
    /// - Parameters:
    ///   - qrCode: 票券 QR Code
    ///   - eventId: 活動 ID
    static func scanTicket(qrCode: String, eventId: String) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/events/\(eventId)/scan")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = ["qrCode": qrCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ActivitiesAPIError.requestFailed("Invalid response")
        }
        
        switch http.statusCode {
        case 200...299:
            return
        case 400:
            throw ActivitiesAPIError.ticketInvalid
        default:
            throw ActivitiesAPIError.requestFailed("HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - 創建投票
    
    /// 創建投票/問卷
    /// - Parameters:
    ///   - title: 投票標題
    ///   - description: 投票描述
    ///   - options: 選項列表
    ///   - multipleChoice: 是否多選
    ///   - deadline: 截止時間
    ///   - groupId: 組織 ID
    /// - Returns: 投票 ID
    static func createPoll(
        title: String,
        description: String,
        options: [String],
        multipleChoice: Bool,
        deadline: Date,
        groupId: String
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/polls")
        else {
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "title": title,
            "description": description,
            "options": options,
            "multipleChoice": multipleChoice,
            "deadline": ISO8601DateFormatter().string(from: deadline),
            "groupId": groupId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ActivitiesAPIError.requestFailed("Failed to create poll")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = obj["id"] as? String {
            return id
        }
        
        return "remote-\(UUID().uuidString)"
    }
    
    // MARK: - 投票
    
    /// 提交投票
    /// - Parameters:
    ///   - pollId: 投票 ID
    ///   - userId: 用戶 ID
    ///   - selections: 選擇的選項索引
    static func vote(
        pollId: String,
        userId: String,
        selections: [Int]
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/polls/\(pollId)/vote")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "userId": userId,
            "selections": selections
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ActivitiesAPIError.requestFailed("Invalid response")
        }
        
        switch http.statusCode {
        case 200...299:
            return
        case 409:
            throw ActivitiesAPIError.alreadyVoted
        default:
            throw ActivitiesAPIError.requestFailed("HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - 獲取投票結果
    
    /// 獲取投票結果
    static func fetchPollResults(pollId: String) async throws -> PollResults {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/activities/polls/\(pollId)/results")
        else {
            // 離線模式
            return PollResults(
                totalVotes: 150,
                optionCounts: [85, 45, 20]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ActivitiesAPIError.requestFailed("Failed to fetch poll results")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PollResults.self, from: data)
    }
}

// MARK: - 輔助數據結構

struct TicketInfo: Codable {
    let ticketId: String
    let qrCode: String
    let eventId: String
    let userId: String
}

struct PollResults: Codable {
    let totalVotes: Int
    let optionCounts: [Int]
}

