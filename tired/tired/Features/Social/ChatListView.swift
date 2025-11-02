import SwiftUI

struct ChatListView: View {
    let session: AppSession
    private let chatService: ChatServiceProtocol = ChatServiceRouter.make()

    @State private var conversations: [Conversation] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var token: CancelableToken?
    @State private var readsToken: CancelableToken?
    @State private var showStart = false
    @State private var navigateTo: Conversation?
    @State private var lastReads: [String: Date] = [:]
    @State private var unreadCounts: [String: Int] = [:]
    @State private var unreadRefreshTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && conversations.isEmpty {
                    ProgressView("載入中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    Text("尚無對話")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { convo in
                        NavigationLink {
                            ChatThreadView(session: session, conversation: convo, chatService: chatService)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color.blue.opacity(0.15)).frame(width: 42, height: 42)
                                    .overlay { Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(.blue) }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(convo.title)
                                            .font(.subheadline.weight(.semibold))
                                        if let c = unreadCounts[convo.id], c > 0 {
                                            Text("\(c)")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue, in: Capsule())
                                        } else if isUnread(convo) {
                                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                                        }
                                    }
                                    Text(convo.lastMessagePreview).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(convo.updatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("標為已讀") {
                                Task { await markAsRead(convo) }
                            }
                            .tint(.blue)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("訊息")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await markAllAsRead() }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showStart = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await load() }
            .task { await attachRealtimeOrLoad() }
            .onDisappear { token?.cancel(); token = nil; readsToken?.cancel(); readsToken = nil }
            .sheet(isPresented: $showStart) {
                NavigationStack {
                    ChatStartView(session: session, chatService: chatService) { convo in
                        navigateTo = convo
                    }
                }
            }
            .navigationDestination(item: $navigateTo) { convo in
                ChatThreadView(session: session, conversation: convo, chatService: chatService)
            }
        }
        .background(Color.bg.ignoresSafeArea(.all))
    }

    private var filtered: [Conversation] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return conversations }
        let q = searchText.lowercased()
        return conversations.filter { $0.title.lowercased().contains(q) || $0.lastMessagePreview.lowercased().contains(q) }
    }

    @MainActor
    private func load() async {
        isLoading = true
        conversations = await chatService.conversations(for: session.user.id)
        isLoading = false
    }

    @MainActor
    private func attachRealtimeOrLoad() async {
        if let realtime = chatService as? ChatRealtimeListening {
            token = realtime.listenConversations(for: session.user.id) { items in
                self.conversations = items
                scheduleRefreshUnread(for: items)
            }
            if let readsRealtime = chatService as? ReadsRealtimeListening {
                readsToken = readsRealtime.listenAllReads(for: session.user.id) { map in
                    self.lastReads = map
                    scheduleRefreshUnread(for: self.conversations)
                }
            }
        } else {
            await load()
        }
    }

    private func isUnread(_ convo: Conversation) -> Bool {
        if let last = lastReads[convo.id] { return convo.updatedAt > last }
        // fallback to local persisted time
        if let localLast = ReadStateStore.shared.lastOpened(conversationId: convo.id) { return convo.updatedAt > localLast }
        return true
    }

    @MainActor
    private func refreshUnread(for items: [Conversation]) async {
        var next: [String: Int] = unreadCounts
        for convo in items {
            let count = await chatService.unreadCount(conversationId: convo.id, userId: session.user.id, sampleLimit: 50)
            next[convo.id] = count
        }
        unreadCounts = next
    }

    @MainActor
    private func scheduleRefreshUnread(for items: [Conversation]) {
        unreadRefreshTask?.cancel()
        unreadRefreshTask = Task { [items] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            await refreshUnread(for: items)
        }
    }

    @MainActor
    private func markAsRead(_ convo: Conversation) async {
        lastReads[convo.id] = Date()
        unreadCounts[convo.id] = 0
        ReadStateStore.shared.markOpened(conversationId: convo.id)
        await chatService.markRead(conversationId: convo.id, userId: session.user.id)
    }

    @MainActor
    private func markAllAsRead() async {
        let now = Date()
        for convo in conversations {
            lastReads[convo.id] = now
            unreadCounts[convo.id] = 0
            ReadStateStore.shared.markOpened(conversationId: convo.id, at: now)
            await chatService.markRead(conversationId: convo.id, userId: session.user.id)
        }
    }
}
