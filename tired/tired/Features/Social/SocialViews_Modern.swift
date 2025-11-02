import SwiftUI
import Combine

// MARK: - 🎨 聊天列表（現代化版本）

struct ChatListView_Modern: View {
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
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                Group {
                    if isLoading && conversations.isEmpty {
                        loadingView
                    } else if filtered.isEmpty {
                        emptyView
                    } else {
                        conversationsList
                    }
                }
            }
            .navigationTitle("訊息")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜尋對話")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticFeedback.light()
                        Task { await markAllAsRead() }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showStart = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
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
    }

    // MARK: - 加載視圖
    
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    SkeletonCard()
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                            value: isLoading
                        )
                }
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - 空狀態
    
    private var emptyView: some View {
        AppEmptyStateView(
            systemImage: "bubble.left.and.bubble.right",
            title: "尚無對話",
            subtitle: "點擊右上角開始新對話"
        )
    }
    
    // MARK: - 對話列表
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, convo in
                    NavigationLink {
                        ChatThreadView(session: session, conversation: convo, chatService: chatService)
                    } label: {
                        ConversationCard(
                            conversation: convo,
                            unreadCount: unreadCounts[convo.id] ?? 0,
                            isUnread: isUnread(convo)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index % 10) * 0.04),
                        value: filtered.count
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            HapticFeedback.light()
                            Task { await markAsRead(convo) }
                        } label: {
                            Label("已讀", systemImage: "checkmark")
                        }
                        .tint(Color.tint)
                    }
                }
            }
            .padding(.top, 12)
        }
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
        unreadRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await refreshUnread(for: items)
        }
    }

    @MainActor
    private func markAsRead(_ convo: Conversation) async {
        ReadStateStore.shared.markOpened(conversationId: convo.id)
        // TODO: 實現 markAsRead API
        // await chatService.markAsRead(conversationId: convo.id, userId: session.user.id)
        if let count = unreadCounts[convo.id], count > 0 {
            unreadCounts[convo.id] = 0
        }
    }

    @MainActor
    private func markAllAsRead() async {
        for convo in conversations {
            await markAsRead(convo)
        }
        HapticFeedback.success()
        ToastCenter.shared.show("已全部標記為已讀", style: .success)
    }
}

// MARK: - 對話卡片

private struct ConversationCard: View {
    let conversation: Conversation
    let unreadCount: Int
    let isUnread: Bool
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 頭像（在線狀態）
            ZStack(alignment: .bottomTrailing) {
                AvatarRing(
                    imageURL: nil,
                    size: 56,
                    ringColor: isUnread ? Color.tint : .neutralLight,
                    ringWidth: isUnread ? 2 : 1
                )
                
                // 在線狀態點
                if isOnline {
                    Circle()
                        .fill(Color.success)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .stroke(Color.card, lineWidth: 2)
                        }
                }
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(conversation.title)
                        .font(.subheadline.weight(isUnread ? .semibold : .regular))
                        .foregroundStyle(Color.labelPrimary)
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TTokens.gradientPrimary, in: Capsule())
                            .shadow(color: Color.tint.opacity(0.3), radius: 4, y: 2)
                    } else if isUnread {
                        Circle()
                            .fill(Color.tint)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(conversation.lastMessagePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 時間
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(TTokens.spacingLG)
        .glassEffect(intensity: 0.7)
    }
    
    private var isOnline: Bool {
        // 模擬在線狀態，實際應該從服務器獲取
        conversation.updatedAt.timeIntervalSinceNow > -300
    }
}

// MARK: - 🎨 好友列表（現代化版本）

struct FriendsView_Modern: View {
    let session: AppSession
    @StateObject private var viewModel: FriendsViewModel

    init(session: AppSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: FriendsViewModel(userId: session.user.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: TTokens.spacingXL) {
                        // 好友邀請區
                        if !viewModel.requests.isEmpty {
                            requestsSection
                        }
                        
                        // 好友列表
                        friendsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("好友")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        // TODO: 添加好友
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
    
    // MARK: - 邀請區
    
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("好友邀請")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.requests.enumerated()), id: \.element.id) { index, request in
                    FriendRequestCard(request: request) {
                        HapticFeedback.medium()
                        Task {
                            await viewModel.accept(request)
                            HapticFeedback.success()
                        }
                    } onDecline: {
                        HapticFeedback.light()
                        Task {
                            await viewModel.decline(request)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.04),
                        value: viewModel.requests.count
                    )
                }
            }
        }
    }
    
    // MARK: - 好友列表
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack {
                Text("好友")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 4)
                
                Spacer()
                
                Text("\(viewModel.friends.count) 位")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if viewModel.friends.isEmpty {
                ContextualCard(
                    type: .info,
                    title: "尚無好友",
                    message: "點擊右上角添加好友"
                ) {
                    EmptyView()
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                        FriendCard(friend: friend)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.98).combined(with: .opacity)
                            ))
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index % 10) * 0.04),
                                value: viewModel.friends.count
                            )
                    }
                }
            }
        }
    }
}

// MARK: - 好友邀請卡片

private struct FriendRequestCard: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 頭像
            AvatarRing(
                imageURL: nil,
                size: 56,
                ringColor: .creative,
                ringWidth: 2
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(request.from.displayName)
                    .font(.subheadline.weight(.semibold))
                
                Text(request.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 操作按鈕
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.danger)
                        .frame(width: 36, height: 36)
                        .background(Color.danger.opacity(0.15), in: Circle())
                }
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.success)
                        .frame(width: 36, height: 36)
                        .background(Color.success.opacity(0.15), in: Circle())
                }
            }
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}

// MARK: - 好友卡片

private struct FriendCard: View {
    let friend: Friend
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 頭像
            AvatarRing(
                imageURL: nil,
                size: 50,
                ringColor: Color.tint,
                ringWidth: 2
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(friend.user.displayName)
                    .font(.subheadline.weight(.semibold))
                
                Text("自 \(friend.since, style: .date) 成為好友")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 快速操作
            Menu {
                Button {
                    HapticFeedback.light()
                    // TODO: 發送訊息
                } label: {
                    Label("發送訊息", systemImage: "message")
                }
                
                Button {
                    HapticFeedback.light()
                    // TODO: 查看資料
                } label: {
                    Label("查看資料", systemImage: "person.crop.circle")
                }
                
                Button(role: .destructive) {
                    HapticFeedback.warning()
                    // TODO: 刪除好友
                } label: {
                    Label("刪除好友", systemImage: "person.crop.circle.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.neutralLight.opacity(0.5), in: Circle())
            }
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}
