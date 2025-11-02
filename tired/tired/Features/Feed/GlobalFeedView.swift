import SwiftUI

struct GlobalFeedView: View {
    let session: AppSession
    let membership: TenantMembership?
    var personalTimelineStore: PersonalTimelineStore?
    let feedService: GlobalFeedServiceProtocol
    private let pageSize = 20

    @State private var posts: [Post] = []
    @State private var nextCursor: FeedCursor?
    @State private var filter = FeedFilter()
    @State private var searchText: String = ""
    @State private var showComposer = false
    @State private var isInitialLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true

    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoading && mergedPosts.isEmpty {
                    AppLoadingView(title: L.s("feed.loading"))
                } else if filteredPosts.isEmpty {
                    AppEmptyStateView(
                        systemImage: "square.and.pencil",
                        title: L.s("feed.empty.title"),
                        subtitle: L.s("feed.empty.subtitle")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
            .navigationTitle(membership == nil ? "探索內容" : "組織動態")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    if personalTimelineStore != nil {
                        Button {
                            showComposer = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜尋貼文或標籤")
            .task(id: filter) {
                await refresh()
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
            Image(systemName: "line.3.horizontal.decrease.circle")
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
