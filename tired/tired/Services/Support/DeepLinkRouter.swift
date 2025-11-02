import Foundation
import Combine

final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published var pendingChatId: String? = nil
    @Published var pendingAttendanceSessId: String? = nil

    private init() {}

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "tired" else { return false }
        // Supported:
        //  - tired://chat?cid=..., tired://chat/cid
        //  - tired://attendance?sessId=..., tired://attendance/<sessId>
        let host = url.host?.lowercased() ?? ""
        if host == "chat" {
            if let cid = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name.lowercased() == "cid" })?.value,
               !cid.isEmpty {
                pendingChatId = cid
                return true
            }
            let last = url.lastPathComponent
            if !last.isEmpty { pendingChatId = last; return true }
        } else if host == "attendance" {
            if let sess = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name.lowercased() == "sessid" })?.value,
               !sess.isEmpty {
                pendingAttendanceSessId = sess
                return true
            }
            let last = url.lastPathComponent
            if !last.isEmpty { pendingAttendanceSessId = last; return true }
        }
        return false
    }
}
