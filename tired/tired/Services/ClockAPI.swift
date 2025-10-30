import Foundation

enum ClockAPIError: Error { case invalidURL, requestFailed }

struct ClockAPI {
    static func submit(siteId: String, uid: String, idempotencyKey: String, ts: Date = Date(), gps: (lat: Double, lng: Double)? = nil) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/clock/records") else {
            // simulate success when endpoint absent
            return "local-\(UUID().uuidString)"
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        var body: [String: Any] = [
            "uid": uid,
            "siteId": siteId,
            "ts": ISO8601DateFormatter().string(from: ts)
        ]
        if let gps { body["gps"] = ["lat": gps.lat, "lng": gps.lng] }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClockAPIError.requestFailed
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let id = obj["id"] as? String {
            return id
        }
        return "remote-\(UUID().uuidString)"
    }
}

