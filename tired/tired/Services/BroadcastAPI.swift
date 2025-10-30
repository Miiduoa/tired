import Foundation

enum BroadcastAPIError: Error {
    case invalidURL
    case requestFailed
}

struct BroadcastAPI {
    static func ack(broadcastId: String, uid: String, idempotencyKey: String? = nil) async throws {
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BroadcastAPIError.requestFailed
        }
    }
}
