import Foundation
import UIKit

enum UploadAPIError: Error { case invalidURL, requestFailed }

struct UploadAPI {
    static func uploadImage(_ image: UIImage) async throws -> URL {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/upload") else {
            // Fallback: data URL
            guard let data = image.jpegData(compressionQuality: 0.85) else { throw UploadAPIError.requestFailed }
            let base64 = data.base64EncodedString()
            return URL(string: "data:image/jpeg;base64,\(base64)")!
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else { throw UploadAPIError.requestFailed }
        let base64 = data.base64EncodedString()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["fileBase64": base64, "mime": "image/jpeg"]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UploadAPIError.requestFailed }
        if let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any], let urlStr = obj["url"] as? String, let out = URL(string: urlStr) {
            return out
        }
        throw UploadAPIError.requestFailed
    }

    static func upload(data: Data, mime: String) async throws -> URL {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/upload") else {
            let base64 = data.base64EncodedString()
            return URL(string: "data:\(mime);base64,\(base64)")!
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.setValue(mime, forHTTPHeaderField: "X-File-Mime")
        let (respData, resp) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UploadAPIError.requestFailed }
        if let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any], let urlStr = obj["url"] as? String, let out = URL(string: urlStr) {
            return out
        }
        throw UploadAPIError.requestFailed
    }

    static func uploadWithProgress(data: Data, mime: String, progress: @escaping (Double) -> Void) async throws -> URL {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/upload") else {
            let base64 = data.base64EncodedString()
            progress(1.0)
            return URL(string: "data:\(mime);base64,\(base64)")!
        }
        class Delegate: NSObject, URLSessionTaskDelegate {
            let cb: (Double) -> Void
            init(cb: @escaping (Double) -> Void) { self.cb = cb }
            func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
                guard totalBytesExpectedToSend > 0 else { return }
                cb(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
            }
        }
        let delegate = Delegate(cb: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.setValue(mime, forHTTPHeaderField: "X-File-Mime")
        let (respData, resp) = try await session.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UploadAPIError.requestFailed }
        if let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any], let urlStr = obj["url"] as? String, let out = URL(string: urlStr) {
            progress(1.0)
            return out
        }
        throw UploadAPIError.requestFailed
    }
}
