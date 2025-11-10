import SwiftUI
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var requests: [FriendRequest] = []
    private let service: FriendsServiceProtocol
    private let userId: String
    private var friendsToken: CancelableToken?
    private var requestsToken: CancelableToken?

    init(userId: String, service: FriendsServiceProtocol = FriendsServiceRouter.make()) {
        self.userId = userId
        self.service = service
    }

    func load() async {
        if let realtime = service as? FriendsRealtimeListening {
            friendsToken?.cancel(); requestsToken?.cancel()
            friendsToken = realtime.listenFriends(of: userId) { [weak self] items in self?.friends = items }
            requestsToken = realtime.listenRequests(for: userId) { [weak self] items in self?.requests = items }
        } else {
            async let f = service.friends(of: userId)
            async let r = service.requests(for: userId)
            friends = await f
            requests = await r
        }
    }

    func accept(_ request: FriendRequest) async {
        try? await service.accept(requestId: request.id, for: userId)
        await load()
    }

    func decline(_ request: FriendRequest) async {
        try? await service.decline(requestId: request.id, for: userId)
        await load()
    }

    func sendRequest(to identifier: String) async -> Result<Void, Error> {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(FriendsError.emptyIdentifier)
        }
        do {
            try await service.sendRequest(from: userId, to: trimmed)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func remove(_ friend: Friend) async -> Result<Void, Error> {
        do {
            try await service.removeFriend(friendId: friend.user.id, for: userId)
            await load()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    enum FriendsError: LocalizedError {
        case emptyIdentifier

        var errorDescription: String? {
            switch self {
            case .emptyIdentifier: return "請輸入好友帳號或 ID"
            }
        }
    }
}

struct FriendsView: View {
    let session: AppSession
    @StateObject private var viewModel: FriendsViewModel

    init(session: AppSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: FriendsViewModel(userId: session.user.id))
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.requests.isEmpty {
                    Section("好友邀請") {
                        ForEach(viewModel.requests) { req in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(req.from.displayName).font(.subheadline.weight(.semibold))
                                    Text(req.createdAt, style: .time).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("接受") { Task { await viewModel.accept(req) } }
                                Button("拒絕") { Task { await viewModel.decline(req) } }.foregroundColor(.red)
                            }
                        }
                    }
                }

                Section("好友") {
                    if viewModel.friends.isEmpty {
                        Text("尚無好友")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.friends) { f in
                            HStack {
                                Circle().fill(Color.green.opacity(0.15)).frame(width: 36, height: 36)
                                    .overlay { Image(systemName: "person.fill").foregroundStyle(.green) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.user.displayName).font(.subheadline.weight(.medium))
                                    Text("自 \(f.since, style: .date) 成為好友").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("好友")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
        .background(Color.bg.ignoresSafeArea(.all))
    }
}
