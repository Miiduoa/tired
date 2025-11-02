import SwiftUI

struct GlobalFeedView: View {
    let session: AppSession
    let membership: TenantMembership?
    var personalTimelineStore: PersonalTimelineStore?
    let feedService: GlobalFeedServiceProtocol
    var onSwitchTenant: ((String) -> Void)? = nil
    private let pageSize = 20

    @State private var posts: [Post] = []
    @State private var nextCursor: FeedCursor?
    @State private var filter = FeedFilter()
    @State private var searchText: String = ""
    @State private var showComposer = false
    @State private var isInitialLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var showCapabilityPanel = true
    @State private var didLoadFilterPrefs = false

    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoading && mergedPosts.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { _ in
                                FeedSkeletonRow().padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 12)
                    }
                } else if filteredPosts.isEmpty {
                    AppEmptyStateView(
                        systemImage: "square.and.pencil",
                        title: L.s("feed.empty.title"),
                        subtitle: L.s("feed.empty.subtitle")
                    )
                } else {
                    ScrollView {
                        filterBar
                            .padding(.vertical, 4)
                        LazyVStack(spacing: 12) {
                            if let m = membership, showCapabilityPanel {
                                capabilityPanel(for: m)
                                    .padding(.horizontal, 16)
                            } else if let m = membership {
                                capabilityStrip(for: m)
                                    .padding(.horizontal, 16)
                            }
                            ForEach(filteredPosts) { post in
                                PostRowView(post: post)
                                    .cardStyle(padding: 16, radius: TTokens.radiusLG, shadowLevel: 1)
                                    .padding(.horizontal, 16)
                                    .onAppear {
                                        guard post.id == filteredPosts.last?.id else { return }
                                        Task { await loadPage(reset: false) }
                                    }
                            }
                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 16)
                            } else if hasMore {
                                Button {
                                    Task { await loadPage(reset: false) }
                                } label: {
                                    Label("載入更多", systemImage: "arrow.down.to.line")
                                }
                                .font(.footnote)
                                .padding(.vertical, 12)
                                .tSecondaryButton()
                            }
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("動態")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if let m = membership {
                            Button { showCapabilityPanel.toggle() } label: {
                                Image(systemName: showCapabilityPanel ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            }
                            Menu {
                                if m.hasAccess(to: .attendance) {
                                    NavigationLink(destination: AttendanceView(membership: m)) { Label("簽到/點名", systemImage: "qrcode.viewfinder") }
                                }
                                if m.hasAccess(to: .clock) {
                                    NavigationLink(destination: ClockView(membership: m)) { Label("打卡", systemImage: "mappin.circle") }
                                }
                                if m.hasAccess(to: .broadcast) {
                                    NavigationLink(destination: BroadcastListView(membership: m)) { Label("公告", systemImage: "megaphone.fill") }
                                }
                            } label: { Image(systemName: "plus.circle") }
                        }
                        if personalTimelineStore != nil {
                            Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜尋貼文或標籤")
            .task(id: filter) {
                await refresh()
            }
            .onChange(of: filter) { newValue in
                FeedFilterStore().save(newValue, for: session.user.id)
            }
            .task(id: session.user.id) {
                if !didLoadFilterPrefs {
                    filter = FeedFilterStore().load(userId: session.user.id)
                    didLoadFilterPrefs = true
                }
            }
            .sheet(isPresented: $showComposer) {
                PersonalPostComposerView { summary, content, category, visibility, attachments in
                    guard let store = personalTimelineStore else { return }
                    try await store.create(summary: summary, content: content, category: category, visibility: visibility, attachments: attachments)
                    await refresh()
                }
            }
            .refreshable {
                await refresh()
            }
        }
    }

    // MARK: - Filter Bar (固定在列表頂部)
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 來源：全部 / 組織 / 個人
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "全部", selected: !filter.onlyOrganizations && !filter.onlyPersonal, color: .tint) {
                        filter.onlyOrganizations = false
                        filter.onlyPersonal = false
                    }
                    chip(title: "組織", selected: filter.onlyOrganizations, color: .purple) {
                        filter.onlyOrganizations = true
                        filter.onlyPersonal = false
                    }
                    chip(title: "個人", selected: filter.onlyPersonal, color: .blue) {
                        filter.onlyOrganizations = false
                        filter.onlyPersonal = true
                    }
                }
                .padding(.horizontal, 16)
            }
            // 可見度
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "全部", selected: filter.visibility == nil, color: .gray) {
                        filter.visibility = nil
                    }
                    ForEach(PostVisibility.allCases) { vis in
                        chip(title: vis.label, selected: filter.visibility == vis, color: .orange) {
                            filter.visibility = vis
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            // 類別
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "全部類別", selected: filter.categories.isEmpty, color: .gray) {
                        filter.categories = []
                    }
                    ForEach(PostCategory.allCases) { cat in
                        chip(title: cat.displayName, selected: filter.categories.contains(cat), color: .green) {
                            if let idx = filter.categories.firstIndex(of: cat) {
                                filter.categories.remove(at: idx)
                            } else {
                                filter.categories.append(cat)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func chip(title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(selected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((selected ? color.opacity(0.18) : Color.neutralLight), in: Capsule())
                .foregroundStyle(selected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var mergedPosts: [Post] {
        var combined = posts
        if let personalPosts = personalTimelineStore?.posts {
            let existingIds = Set(combined.map { $0.id })
            combined.append(contentsOf: personalPosts.filter { !existingIds.contains($0.id) })
        }
        return combined.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var filteredPosts: [Post] {
        var result = mergedPosts
        if let membership {
            result = result.filter { post in
                guard post.visibility != .privateOnly else { return post.sourceId == session.user.id }
                if post.visibility == .organizations {
                    return post.sourceType == .organization || post.metadata["targetOrgId"] == membership.id
                }
                return true
            }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let tokens = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            result = result.filter { post in
                post.summary.lowercased().contains(tokens) ||
                post.content.lowercased().contains(tokens) ||
                post.tags.contains(where: { $0.lowercased().contains(tokens) })
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var filterMenu: some View {
        Menu {
            Button("全部") { filter = FeedFilter() }
            Button("僅組織內容") { filter = FeedFilter(onlyOrganizations: true) }
            Button("僅個人貼文") { filter = FeedFilter(onlyPersonal: true) }
            Divider()
            Menu("可見度") {
                ForEach(PostVisibility.allCases) { vis in
                    Button(vis.label) {
                        filter.visibility = vis
                    }
                }
                Button("清除") { filter.visibility = nil }
            }
        } label: {
            HStack(spacing: 12) {
                if session.allMemberships.count > 1 {
                    Menu {
                        ForEach(session.allMemberships, id: \.id) { m in
                            Button {
                                onSwitchTenant?(m.id)
                            } label: {
                                Label(m.tenant.name, systemImage: m.id == membership?.id ? "checkmark" : "building.2")
                            }
                        }
                    } label: {
                        Label(membership?.tenant.name ?? "我的組織", systemImage: "building.2.fill")
                    }
                }
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
    
    // MARK: - Capability Panel
    @ViewBuilder
    private func capabilityPanel(for membership: TenantMembership) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("能力捷徑").font(.headline)
            VStack(spacing: 12) {
                if membership.hasAccess(to: .broadcast) {
                    TCard(title: "公告", subtitle: "查看公告與回條", trailingSystemImage: "megaphone.fill") {
                        NavigationLink("前往公告列表") { BroadcastListView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
                if membership.hasAccess(to: .attendance) {
                    TCard(title: "10 秒點名", subtitle: "今日課程/場次", trailingSystemImage: "qrcode.viewfinder") {
                        NavigationLink("開啟點名") { AttendanceView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
                if membership.hasAccess(to: .clock) {
                    TCard(title: "打卡", subtitle: "據點與外勤", trailingSystemImage: "mappin.circle") {
                        NavigationLink("前往打卡") { ClockView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
                if membership.hasAccess(to: .esg) {
                    TCard(title: "ESG", subtitle: "帳單 OCR 與月報", trailingSystemImage: "leaf.fill") {
                        NavigationLink("開啟 ESG") { ESGOverviewView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
                if membership.hasAccess(to: .activities) {
                    TCard(title: "活動", subtitle: "報名/票券/入場", trailingSystemImage: "calendar") {
                        NavigationLink("查看活動") { ActivityBoardView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
                if membership.hasAccess(to: .insights) {
                    TCard(title: "分析", subtitle: "群組儀表板", trailingSystemImage: "chart.line.uptrend.xyaxis") {
                        NavigationLink("查看儀表板") { InsightsView(membership: membership) }
                            .tPrimaryButton(fullWidth: true)
                    }
                }
            }
        }
    }

    @MainActor
    private func refresh() async {
        async let timelineTask = loadPersonalTimeline()
        await loadPage(reset: true)
        await timelineTask
    }
    
    @MainActor
    private func loadPersonalTimeline() async {
        await personalTimelineStore?.load()
    }
    
    @MainActor
    private func loadPage(reset: Bool) async {
        if reset {
            if isInitialLoading { return }
            isInitialLoading = true
            posts.removeAll()
            nextCursor = nil
            hasMore = true
        } else {
            guard hasMore, !isLoadingMore, !isInitialLoading else { return }
            isLoadingMore = true
        }
        let cursor = reset ? nil : nextCursor
        let page = await feedService.fetchPosts(for: session.user, filter: filter, after: cursor, limit: pageSize)
        if reset {
            posts = page.posts
        } else {
            append(posts: page.posts)
        }
        nextCursor = page.nextCursor
        hasMore = page.nextCursor != nil
        isInitialLoading = false
        isLoadingMore = false
    }
    
    @MainActor
    private func append(posts newPosts: [Post]) {
        guard !newPosts.isEmpty else { return }
        var existing = Set(posts.map { $0.id })
        for post in newPosts where !existing.contains(post.id) {
            posts.append(post)
            existing.insert(post.id)
        }
    }
}
