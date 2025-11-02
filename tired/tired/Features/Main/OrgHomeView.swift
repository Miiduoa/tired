import SwiftUI

struct OrgHomeView: View {
    let session: AppSession
    let membership: TenantMembership
    @StateObject private var moduleManager = TenantModuleManager()
    @State private var quickActions: [TenantModuleEntryAction] = []
    
    private var modules: [AppModule] {
        moduleManager.availableModules(for: membership)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if !quickActions.isEmpty { quickActionsSection }
                    capabilityCards
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("首頁")
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task(id: membership.id) { await loadQuickActions() }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(membership.tenant.name)
                .font(.title2.weight(.semibold))
            HStack(spacing: 8) {
                Label(membership.tenant.type.displayName, systemImage: "building.2")
                Label(membership.role.displayName, systemImage: "person.fill.badge.plus")
                Label(membership.capabilityPack.name, systemImage: "puzzlepiece.extension")
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TTokens.radiusLG))
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速操作").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(quickActions) { action in
                    QuickActionCard(action: action)
                }
            }
        }
    }
    
    @ViewBuilder
    private var capabilityCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            if membership.hasAccess(to: .broadcast) {
                TCard(title: "公告", subtitle: "查看公告與回條", trailingSystemImage: "megaphone.fill") {
                    NavigationLink("前往公告列表") { BroadcastListView(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .attendance) {
                TCard(title: "10 秒點名", subtitle: "今日課程/場次", trailingSystemImage: "qrcode.viewfinder") {
                    NavigationLink("開啟點名") { AttendanceView_Modern(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .clock) {
                TCard(title: "打卡", subtitle: "據點與外勤", trailingSystemImage: "mappin.circle") {
                    NavigationLink("前往打卡") { ClockView_Modern(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .esg) {
                TCard(title: "ESG", subtitle: "帳單 OCR 與月報", trailingSystemImage: "leaf.fill") {
                    NavigationLink("開啟 ESG") { ESGOverviewView_Modern(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .activities) {
                TCard(title: "活動", subtitle: "報名/票券/入場", trailingSystemImage: "calendar") {
                    NavigationLink("查看活動") { ActivityBoardView_Modern(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .insights) {
                TCard(title: "分析", subtitle: "群組儀表板", trailingSystemImage: "chart.line.uptrend.xyaxis") {
                    NavigationLink("查看儀表板") { InsightsView_Modern(membership: membership) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .feed) {
                TCard(title: "動態", subtitle: "最新貼文與公告", trailingSystemImage: "square.grid.2x2") {
                    NavigationLink("前往動態") { GlobalFeedView(session: session, membership: membership, personalTimelineStore: nil, feedService: GlobalFeedService()) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .chat) {
                TCard(title: "訊息", subtitle: "群聊/私訊", trailingSystemImage: "message.fill") {
                    NavigationLink("開啟訊息") { ChatListView(session: session) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
            if membership.hasAccess(to: .friends) {
                TCard(title: "好友", subtitle: "邀請與名單", trailingSystemImage: "person.2.fill") {
                    NavigationLink("管理好友") { FriendsView(session: session) }
                        .tPrimaryButton(fullWidth: true)
                }
            }
        }
    }
    
    @MainActor
    private func loadQuickActions() async {
        async let actions = moduleManager.quickActions(for: modules, session: session) { _ in }
        quickActions = await actions
    }
}

// MARK: - Local QuickActionCard (shared樣式)
private struct QuickActionCard: View {
    let action: TenantModuleEntryAction
    
    var body: some View {
        Button(action: action.action) {
            VStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundStyle(action.color)
                Text(action.title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                if let badge = action.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(action.color.opacity(0.15), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

