import Foundation

enum AttendanceAPIError: Error { case invalidURL, requestFailed }

struct AttendanceAPI {
    struct CreatedSession: Decodable { let id: String; let qr_seed: String? }

    static func submitCheck(sessId: String, uid: String, idempotencyKey: String, ts: Date = Date()) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/check") else {
            return "local-\(UUID().uuidString)"
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        let body: [String: Any] = [
            "sessId": sessId,
            "uid": uid,
            "ts": ISO8601DateFormatter().string(from: ts)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let id = obj["id"] as? String {
            return id
        }
        return "remote-\(UUID().uuidString)"
    }

    static func createSession(courseId: String, policyId: String = "default", openAt: Date, closeAt: Date) async throws -> CreatedSession {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/sessions") else {
            return CreatedSession(id: "local-\(UUID().uuidString)", qr_seed: nil)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "courseId": courseId,
            "policyId": policyId,
            "open_at": ISO8601DateFormatter().string(from: openAt),
            "close_at": ISO8601DateFormatter().string(from: closeAt)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AttendanceAPIError.requestFailed
        }
        if let created = try? JSONDecoder().decode(CreatedSession.self, from: data) { return created }
        return CreatedSession(id: "remote-\(UUID().uuidString)", qr_seed: nil)
    }

    static func closeSession(sessId: String) async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/attendance/sessions/\(sessId)/close") else {
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: req)
    }
}
