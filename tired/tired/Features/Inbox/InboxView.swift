
import SwiftUI
import Combine

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var items: [InboxItem] = []
    @Published private(set) var isLoading = false
    
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    private var ackInFlight: Set<String> = []
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        let fetched = await service.inboxItems(for: membership)
        withAnimation(TTokens.animationSmooth) {
            items = fetched.deduped().sorted { lhs, rhs in
                let lhsTime = lhs.deadline ?? .distantFuture
                let rhsTime = rhs.deadline ?? .distantFuture
                return lhsTime < rhsTime
            }
        }
    }
    
    func acknowledge(item: InboxItem) async {
        guard !ackInFlight.contains(item.id) else { return }
        ackInFlight.insert(item.id)
        defer { ackInFlight.remove(item.id) }
        
        do {
            try await service.acknowledgeInboxItem(item, membership: membership)
            withAnimation(TTokens.animationStandard) {
                items.removeAll { $0.id == item.id }
            }
        } catch {
            // 將 ACK 入列 Outbox，稍後重試；UI 仍先移除避免重複處理
            OutboxService.shared.enqueueInboxAck(inboxItemId: item.id, membershipId: membership.id)
            withAnimation(TTokens.animationStandard) {
                items.removeAll { $0.id == item.id }
            }
            print("⚠️ 無法標記收件項目 \(item.id)：\(error.localizedDescription)")
        }
    }

    func acknowledgeAll() async {
        // 建立快照，避免遍歷時修改同一陣列造成問題
        let pending = items
        await withTaskGroup(of: Void.self) { group in
            for item in pending {
                group.addTask { [weak self] in
                    await self?.acknowledge(item: item)
                }
            }
        }
    }
}

struct InboxView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: InboxViewModel
    @State private var selectedKind: InboxItem.Kind? = nil
    @State private var searchText = ""
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: InboxViewModel(membership: membership, service: service))
    }
    
    private var filteredItems: [InboxItem] {
        viewModel.items.filter { item in
            // 種類過濾
            if let selectedKind, item.kind != selectedKind {
                return false
            }
            // 搜尋過濾
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return item.title.lowercased().contains(query) ||
                       item.subtitle.lowercased().contains(query)
            }
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        AppLoadingView(title: L.s("inbox.loading"))
                    } else if filteredItems.isEmpty {
                        AppEmptyStateView(
                            systemImage: "tray.fill",
                            title: L.s("inbox.empty.title"),
                            subtitle: selectedKind == nil ? L.s("inbox.empty.subtitle.all") : L.s("inbox.empty.subtitle.filtered")
                        )
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("收件匣")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.acknowledgeAll() }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .disabled(viewModel.items.isEmpty)
                }
            }
            .searchable(text: $searchText, prompt: "搜尋收件項目")
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: TTokens.spacingMD) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    InboxItemCard(item: item, index: index)
                        .onTapGesture {
                            Task {
                                await viewModel.acknowledge(item: item)
                            }
                        }
                }
            }
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.vertical, TTokens.spacingMD)
        }
    }
    
    // loading/empty 改用通用元件
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            Button(action: { selectedKind = nil }) {
                HStack {
                    Text("全部")
                    if selectedKind == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            ForEach(InboxItem.Kind.allCases, id: \.self) { kind in
                Button(action: { selectedKind = kind }) {
                    HStack {
                        Text(kind.displayName)
                        if selectedKind == kind {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(Color.tint)
        }
    }
}

// MARK: - Inbox Item Card

private struct InboxItemCard: View {
    let item: InboxItem
    let index: Int
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 圖示和顏色指示
            iconSection
            
            // 內容區
            VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if item.isUrgent {
                        urgentBadge
                    }
                }
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                footerInfo
            }
        }
        .padding(TTokens.spacingLG)
        .background(cardBackground)
        .shadow(
            color: TTokens.shadowLevel1.color,
            radius: TTokens.shadowLevel1.radius,
            y: TTokens.shadowLevel1.y
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(TTokens.animationQuick, value: isPressed)
        .onTapGesture {
            handleTap()
        }
    }
    
    // MARK: - Subviews
    
    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(kindColor(for: item.kind).opacity(0.15))
                .frame(width: 48, height: 48)
            
            Image(systemName: iconName(for: item.kind))
                .font(.title3)
                .foregroundStyle(kindColor(for: item.kind))
        }
    }
    
    private var urgentBadge: some View {
        Label("緊急", systemImage: "exclamationmark.circle.fill")
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.horizontal, TTokens.spacingXS)
            .padding(.vertical, TTokens.spacingXS / 2)
            .background(.red.opacity(0.1), in: Capsule())
    }
    
    private var footerInfo: some View {
        HStack(spacing: TTokens.spacingSM) {
            // 優先級標籤
            priorityBadge
            
            // 截止時間
            if let deadline = item.deadline {
                deadlineLabel(deadline)
            }
            
            Spacer()
            
            // 種類標籤
            kindBadge
        }
    }
    
    private var priorityBadge: some View {
        HStack(spacing: TTokens.spacingXS) {
            Circle()
                .fill(item.priority.color)
                .frame(width: 6, height: 6)
            
            Text(item.priority.displayName)
                .font(.caption)
                .foregroundStyle(item.priority.color)
        }
    }
    
    private func deadlineLabel(_ deadline: Date) -> some View {
        Text(deadline, style: .time)
            .font(.caption)
            .foregroundStyle(timeColor(for: deadline))
    }
    
    private var kindBadge: some View {
        Text(item.kind.displayName)
            .font(.caption2)
            .padding(.horizontal, TTokens.spacingSM)
            .padding(.vertical, TTokens.spacingXS)
            .background(kindColor(for: item.kind).opacity(0.15), in: Capsule())
            .foregroundStyle(kindColor(for: item.kind))
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
            .fill(Color.card)
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                    .strokeBorder(
                        item.isUrgent ? Color.danger.opacity(0.3) : Color.separator.opacity(0.5),
                        lineWidth: item.isUrgent ? 1.5 : 0.5
                    )
            }
    }
    
    // MARK: - Helpers
    
    private func handleTap() {
        withAnimation(TTokens.animationQuick) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(TTokens.animationQuick) {
                isPressed = false
            }
        }
    }
    
    private func iconName(for kind: InboxItem.Kind) -> String {
        switch kind {
        case .ack: return "checkmark.circle.fill"
        case .rollcall: return "qrcode.viewfinder"
        case .clockin: return "clock.fill"
        case .assignment: return "doc.fill"
        case .esgTask: return "leaf.fill"
        }
    }
    
    private func kindColor(for kind: InboxItem.Kind) -> Color {
        switch kind {
        case .ack: return .tint
        case .rollcall: return .warn
        case .clockin: return .success
        case .assignment: return .creative
        case .esgTask: return .success
        }
    }
    
    private func timeColor(for deadline: Date) -> Color {
        let timeUntil = deadline.timeIntervalSinceNow
        if timeUntil < 0 {
            return .danger
        } else if timeUntil < 3600 { // 1小時內
            return .warn
        } else {
            return .secondary
        }
    }
}

// MARK: - Extensions

extension InboxItem.Kind {
    var displayName: String {
        switch self {
        case .ack: return "確認"
        case .rollcall: return "點名"
        case .clockin: return "打卡"
        case .assignment: return "作業"
        case .esgTask: return "ESG"
        }
    }
}

extension InboxItem.Priority {
    var displayName: String {
        switch self {
        case .low: return "低"
        case .normal: return "普通"
        case .high: return "高"
        case .urgent: return "緊急"
        }
    }
}
