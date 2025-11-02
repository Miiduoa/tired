
import SwiftUI
import Combine

@MainActor
final class BroadcastListViewModel: ObservableObject {
    @Published private(set) var items: [BroadcastListItem] = []
    @Published private(set) var isLoading = false
    
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        let fetched = await service.broadcasts(for: membership)
        withAnimation(TTokens.animationSmooth) {
            items = fetched.deduped().sorted { lhs, rhs in
                let lDeadline = lhs.deadline ?? .distantFuture
                let rDeadline = rhs.deadline ?? .distantFuture
                return lDeadline < rDeadline
            }
        }
    }
    
    func ack(_ item: BroadcastListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(TTokens.animationStandard) {
            items[index].acked = true
        }
    }
}

struct BroadcastListView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: BroadcastListViewModel
    @ObservedObject private var ackStore = AckStore.shared
    @State private var query = ""
    @EnvironmentObject private var authService: AuthService
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: BroadcastListViewModel(membership: membership, service: service))
    }
    
    private var filteredItems: [BroadcastListItem] {
        guard !query.isEmpty else { return viewModel.items }
        return viewModel.items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            item.body.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.items.isEmpty {
                    AppLoadingView(title: L.s("broadcast.loading"))
                } else if filteredItems.isEmpty {
                    AppEmptyStateView(
                        systemImage: "megaphone.fill",
                        title: L.s("broadcast.empty.title"),
                        subtitle: L.s("broadcast.empty.subtitle")
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("公告")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "搜尋公告")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: TTokens.spacingMD) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    BroadcastCard(
                        item: item,
                        isAcked: ackStore.isAcked(item.id),
                        index: index
                    ) {
                        Task {
                            guard let uid = authService.currentUser?.id, !uid.isEmpty else {
                                // 未登入或無 uid，仍進行本地標記
                                AckStore.shared.ack(item.id)
                                viewModel.ack(item)
                                return
                            }
                            let key = "ack-\(UUID().uuidString)"
                            // 先入列 Outbox，確保即使崩潰也能補送
                            OutboxService.shared.enqueueBroadcastAck(broadcastId: item.id, uid: uid, idempotencyKey: key)
                            do {
                                try await BroadcastAPI.ack(broadcastId: item.id, uid: uid, idempotencyKey: key)
                                // 成功後嘗試清空 outbox（會移除剛入列的同鍵項）
                                await OutboxService.shared.flush(for: uid)
                            } catch {
                                // 保留 outbox 項目，稍後重試
                            }
                            AckStore.shared.ack(item.id)
                            viewModel.ack(item)
                        }
                    }
                }
            }
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.vertical, TTokens.spacingMD)
        }
    }
    
    // MARK: - Loading View
    
    // loading/empty 改用通用元件
}

// MARK: - Broadcast Card

private struct BroadcastCard: View {
    let item: BroadcastListItem
    let isAcked: Bool
    let index: Int
    let onAck: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            // 標題和狀態
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    if let deadline = item.deadline {
                        Text(deadline, style: .date)
                            .font(.caption)
                            .foregroundStyle(timeColor(for: deadline))
                    }
                }
                
                Spacer()
                
                // 確認狀態
                if isAcked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else if item.requiresAck {
                    Button(action: onAck) {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 內容
            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // 底部資訊
            HStack {
                if item.requiresAck {
                    Label("需要確認", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(isAcked ? .green : .orange)
                        .padding(.horizontal, TTokens.spacingSM)
                        .padding(.vertical, TTokens.spacingXS)
                        .background(
                            (isAcked ? Color.green : Color.orange).opacity(0.1),
                            in: Capsule()
                        )
                }
                
                Spacer()
                
                if item.eventId != nil {
                    Label("事件", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle(padding: TTokens.spacingLG, radius: TTokens.radiusLG, shadowLevel: 1)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(isAcked ? 0.8 : 1.0)
        .animation(TTokens.animationQuick, value: isPressed)
        .animation(TTokens.animationStandard, value: isAcked)
        .onTapGesture {
            withAnimation(TTokens.animationQuick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(TTokens.animationQuick) {
                    isPressed = false
                }
            }
        }
    }
    
    private func timeColor(for deadline: Date) -> Color {
        let timeUntil = deadline.timeIntervalSinceNow
        if timeUntil < 0 {
            return .danger
        } else if timeUntil < 86400 { // 24小時內
            return .warn
        } else {
            return .secondary
        }
    }
}
