import Foundation
import CoreLocation

enum AttendanceAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case invalidQRCode
    case sessionExpired
    case alreadyCheckedIn
    case locationRequired
}

/// 點名 API 服務
struct AttendanceAPI {
    
    // MARK: - 學生簽到
    
    /// 學生掃描 QR Code 簽到
    /// - Parameters:
    ///   - userId: 用戶 ID
    ///   - sessionId: 點名會話 ID（從 QR Code 獲取）
    ///   - location: GPS 位置（可選）
    ///   - deviceHash: 設備哈希（防止代簽）
    static func checkIn(
        userId: String,
        sessionId: String,
        location: CLLocationCoordinate2D? = nil,
        deviceHash: String? = nil
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/check-in")
        else {
            // 離線模式：模擬成功
            try await Task.sleep(nanoseconds: 300_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("check-in-\(UUID().uuidString)", forHTTPHeaderField: "Idempotency-Key")
        
        var payload: [String: Any] = [
            "userId": userId,
            "sessionId": sessionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let location = location {
            payload["location"] = [
                "lat": location.latitude,
                "lng": location.longitude
            ]
        }
        
        if let deviceHash = deviceHash {
            payload["deviceHash"] = deviceHash
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AttendanceAPIError.requestFailed("Invalid response")
        }
        
        switch http.statusCode {
        case 200...299:
            return
        case 400:
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                if error.code == "ALREADY_CHECKED_IN" {
                    throw AttendanceAPIError.alreadyCheckedIn
                } else if error.code == "INVALID_QR" {
                    throw AttendanceAPIError.invalidQRCode
                }
            }
            throw AttendanceAPIError.requestFailed("Bad request")
        case 410:
            throw AttendanceAPIError.sessionExpired
        default:
            throw AttendanceAPIError.requestFailed("HTTP \(http.statusCode)")
        }
    }
    
    // MARK: - 教師開啟點名會話
    
    /// 教師開啟點名會話
    /// - Parameters:
    ///   - courseId: 課程 ID
    ///   - teacherId: 教師 ID
    ///   - validDuration: 有效時長（秒）
    ///   - requiresLocation: 是否需要位置驗證
    /// - Returns: 會話 ID 和 QR Code 種子
    static func openSession(
        courseId: String,
        teacherId: String,
        validDuration: Int = 1800,
        requiresLocation: Bool = false
    ) async throws -> (sessionId: String, qrSeed: String) {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/sessions")
        else {
            // 離線模式：生成本地會話
            let sessionId = "local-\(UUID().uuidString)"
            let qrSeed = UUID().uuidString
            return (sessionId, qrSeed)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "courseId": courseId,
            "teacherId": teacherId,
            "validDuration": validDuration,
            "requiresLocation": requiresLocation
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed("Failed to open session")
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(SessionResponse.self, from: data)
        return (result.sessionId, result.qrSeed)
    }
    
    // MARK: - 關閉點名會話
    
    /// 教師關閉點名會話
    static func closeSession(sessionId: String, teacherId: String) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/sessions/\(sessionId)/close")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = ["teacherId": teacherId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed("Failed to close session")
        }
    }
    
    // MARK: - 獲取點名統計
    
    /// 獲取點名統計數據
    static func fetchSnapshot(sessionId: String) async throws -> AttendanceSnapshot {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/sessions/\(sessionId)/snapshot")
        else {
            // 離線模式：返回模擬數據
            return AttendanceSnapshot.mock()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed("Failed to fetch snapshot")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AttendanceSnapshot.self, from: data)
    }
    
    // MARK: - 手動補簽
    
    /// 教師為學生手動補簽
    static func manualCheckIn(
        sessionId: String,
        userId: String,
        teacherId: String,
        reason: String
    ) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/manual-check-in")
        else {
            try await Task.sleep(nanoseconds: 200_000_000)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = [
            "sessionId": sessionId,
            "userId": userId,
            "teacherId": teacherId,
            "reason": reason
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed("Failed to manual check-in")
        }
    }
}

// MARK: - 輔助數據結構

private struct ErrorResponse: Codable {
    let code: String
    let message: String
}

private struct SessionResponse: Codable {
    let sessionId: String
    let qrSeed: String
}

// MARK: - Mock 數據擴展

extension AttendanceSnapshot {
    static func mock() -> AttendanceSnapshot {
        return AttendanceSnapshot(
            courseName: "iOS 開發入門",
            attendanceTime: Date(),
            validDuration: 30,
            stats: AttendanceStats(attended: 28, absent: 2, late: 3, total: 33),
            personalRecords: [
                AttendanceRecord(courseName: "iOS 開發入門", date: Date(), status: .present),
                AttendanceRecord(courseName: "SwiftUI 進階", date: Date().addingTimeInterval(-86400), status: .present),
                AttendanceRecord(courseName: "網路程式設計", date: Date().addingTimeInterval(-172800), status: .late)
            ]
        )
    }
}
