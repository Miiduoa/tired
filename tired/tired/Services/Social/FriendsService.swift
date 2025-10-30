import Foundation

protocol FriendsServiceProtocol {
    func friends(of userId: String) async -> [Friend]
    func requests(for userId: String) async -> [FriendRequest]
    func accept(requestId: String, for userId: String) async throws
    func decline(requestId: String, for userId: String) async throws
}

final class FriendsService: FriendsServiceProtocol {
    static let shared = FriendsService()
    private init() {}

    private var friendsStore: [String: [Friend]] = [:] // userId -> friends
    private var requestsStore: [String: [FriendRequest]] = [:] // userId -> incoming requests

    func friends(of userId: String) async -> [Friend] {
        if let cached = friendsStore[userId] { return cached.sorted { $0.since > $1.since } }
        let alex = FriendUser(id: "u_alex", displayName: "Alex", photoURL: nil)
        let mia = FriendUser(id: "u_mia", displayName: "Mia", photoURL: nil)
        friendsStore[userId] = [Friend(id: "f1", user: alex, since: Date().addingTimeInterval(-86400 * 10))]
        requestsStore[userId] = [FriendRequest(id: "r1", from: mia, createdAt: Date().addingTimeInterval(-3600 * 3))]
        return friendsStore[userId] ?? []
    }

    func requests(for userId: String) async -> [FriendRequest] {
        requestsStore[userId] ?? []
    }

    func accept(requestId: String, for userId: String) async throws {
        var reqs = requestsStore[userId] ?? []
        guard let idx = reqs.firstIndex(where: { $0.id == requestId }) else { return }
        let req = reqs.remove(at: idx)
        requestsStore[userId] = reqs
        var fs = friendsStore[userId] ?? []
        fs.append(Friend(id: UUID().uuidString, user: req.from, since: Date()))
        friendsStore[userId] = fs
    }

    func decline(requestId: String, for userId: String) async throws {
        var reqs = requestsStore[userId] ?? []
        reqs.removeAll { $0.id == requestId }
        requestsStore[userId] = reqs
    }
}

