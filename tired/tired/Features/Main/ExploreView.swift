import SwiftUI

struct ExploreView: View {
    let session: AppSession
    private let feedService: GlobalFeedServiceProtocol = GlobalFeedService()
    
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var searchText: String = ""
    @State private var selectedCategories: Set<PostCategory> = []
    @State private var selectedVisibility: PostVisibility? = nil
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView("載入中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPosts.isEmpty {
                    AppEmptyStateView(systemImage: "globe", title: "目前沒有推薦項目", subtitle: "試著調整篩選條件或搜尋關鍵字")
                } else {
                    List(filteredPosts) { post in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(post.category.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15), in: Capsule())
                                Spacer(minLength: 8)
                                Text(post.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(post.summary)
                                .font(.subheadline.weight(.semibold))
                            if !post.content.isEmpty {
                                Text(post.content)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                if let org = post.organizationName, !org.isEmpty {
                                    Label(org, systemImage: "building.2")
                                        .font(.caption2)
                                }
                                Label(post.visibility.label, systemImage: "eye")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.card)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("探索")
            .background(Color.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "搜尋職缺/專案/公告")
            .task { await load() }
            .refreshable { await load(force: true) }
            .sheet(isPresented: $showFilters) { filterSheet }
        }
    }
    
    private var filteredPosts: [Post] {
        let token = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return posts.filter { post in
            let matchText = token.isEmpty || post.summary.lowercased().contains(token) || post.content.lowercased().contains(token) || (post.organizationName?.lowercased().contains(token) ?? false)
            let matchCat = selectedCategories.isEmpty || selectedCategories.contains(post.category)
            let matchVis = (selectedVisibility == nil) || (post.visibility == selectedVisibility!)
            return matchText && matchCat && matchVis
        }
    }
    
    @MainActor
    private func load(force: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        defer { isLoading = false }
        var filter = FeedFilter(onlyOrganizations: true)
        filter.categories = Array(selectedCategories)
        filter.visibility = selectedVisibility
        posts = await feedService.fetchPosts(for: session.user, filter: filter)
    }
    
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("類別") {
                    ForEach(PostCategory.allCases) { cat in
                        Toggle(isOn: Binding(
                            get: { selectedCategories.contains(cat) },
                            set: { v in
                                if v { selectedCategories.insert(cat) } else { selectedCategories.remove(cat) }
                            }
                        )) { Text(cat.displayName) }
                    }
                }
                Section("可見度") {
                    Picker("可見度", selection: Binding(
                        get: { selectedVisibility ?? .public },
                        set: { selectedVisibility = $0 }
                    )) {
                        Text("（不限）").tag(PostVisibility.public as PostVisibility)
                        ForEach(PostVisibility.allCases) { vis in Text(vis.label).tag(vis) }
                    }
                }
                Section { Button("清除篩選") { selectedCategories.removeAll(); selectedVisibility = nil } }
            }
            .navigationTitle("篩選條件")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { showFilters = false } } }
        }
    }
}


