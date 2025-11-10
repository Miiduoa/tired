import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: SearchResults?
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var searchHistory: [String] = []
    @Published private(set) var isSearching = false
    @Published var selectedScope: SearchScopeUI = .all
    
    private let authService: AuthServiceProtocol
    private let searchService = SearchService.shared
    private var searchTask: Task<Void, Never>?
    
    enum SearchScopeUI: String, CaseIterable {
        case all = "全部"
        case posts = "文章"
        case broadcasts = "公告"
        case people = "用戶"
        case events = "活動"
        
        var serviceScope: SearchScope {
            switch self {
            case .all: return .all
            case .posts: return .posts
            case .broadcasts: return .broadcasts
            case .people: return .users
            case .events: return .events
            }
        }
    }
    
    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }
    
    func loadHistory() async {
        // 本地歷史（不區分使用者）
        searchHistory = searchService.getHistory()
    }
    
    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = nil
            return
        }
        
        // 取消之前的搜索
        searchTask?.cancel()
        isSearching = true
        
        searchTask = Task {
            do {
                // 延遲 300ms 以實現 debounce
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                
                let searchResults = try await searchService.search(
                    query: trimmed,
                    scope: selectedScope.serviceScope,
                    groupId: nil,
                    limit: 10
                )
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    results = searchResults
                    isSearching = false
                }
                
                // 保存搜索歷史
                searchService.saveToHistory(trimmed)
            } catch {
                await MainActor.run { isSearching = false }
                print("⚠️ Search failed: \(error)")
            }
        }
    }
    
    func loadSuggestions() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        
        do {
            suggestions = try await searchService.suggestions(for: trimmed, limit: 5)
        } catch {
            print("⚠️ Failed to load suggestions: \(error)")
        }
    }
    
    func clearHistory() async {
        searchService.clearHistory()
        searchHistory = []
    }
}

// MARK: - Main View

struct GlobalSearchView: View {
    @StateObject private var viewModel = GlobalSearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientMeshBackground()
                
                VStack(spacing: 0) {
                    // 搜索欄
                    searchBar
                        .padding(TTokens.spacingLG)
                    
                    // 範圍選擇器
                    scopePicker
                        .padding(.horizontal, TTokens.spacingLG)
                        .padding(.bottom, TTokens.spacingSM)
                    
                    // 內容區
                    if viewModel.query.isEmpty {
                        historyAndSuggestionsView
                    } else if viewModel.isSearching {
                        loadingView
                    } else if let results = viewModel.results {
                        resultsView(results)
                    } else {
                        emptyView
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadHistory()
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: TTokens.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("搜索文章、公告、用戶...", text: $viewModel.query)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .onChange(of: viewModel.query) { _, newValue in
                    Task {
                        await viewModel.loadSuggestions()
                        if newValue.count > 2 {
                            await viewModel.performSearch()
                        }
                    }
                }
                .onSubmit {
                    Task {
                        await viewModel.performSearch()
                    }
                }
            
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(TTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: TTokens.radiusMD)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Scope Picker
    
    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TTokens.spacingSM) {
                ForEach(GlobalSearchViewModel.SearchScopeUI.allCases, id: \.self) { scope in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedScope = scope
                        }
                        HapticFeedback.selection()
                        Task {
                            await viewModel.performSearch()
                        }
                    } label: {
                        Text(scope.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(viewModel.selectedScope == scope ? .white : .secondary)
                            .padding(.horizontal, TTokens.spacingMD)
                            .padding(.vertical, TTokens.spacingSM)
                            .background {
                                if viewModel.selectedScope == scope {
                                    Capsule()
                                        .fill(TTokens.gradientPrimary)
                                } else {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.1))
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - History and Suggestions
    
    private var historyAndSuggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                // 搜索建議
                if !viewModel.suggestions.isEmpty {
                    suggestionSection
                }
                
                // 搜索歷史
                if !viewModel.searchHistory.isEmpty {
                    historySection
                }
                
                // 熱門搜索（Mock）
                popularSection
            }
            .padding(TTokens.spacingLG)
        }
    }
    
    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("建議")
                .font(.headline.weight(.semibold))
            
            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    viewModel.query = suggestion
                    Task { await viewModel.performSearch() }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.backward")
                            .foregroundStyle(.secondary)
                    }
                    .padding(TTokens.spacingMD)
                    .background {
                        RoundedRectangle(cornerRadius: TTokens.radiusMD)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack {
                Text("最近搜索")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("清除") {
                    Task { await viewModel.clearHistory() }
                }
                .font(.caption)
                .foregroundStyle(Color.danger)
            }
            
            ForEach(viewModel.searchHistory, id: \.self) { historyItem in
                Button {
                    viewModel.query = historyItem
                    Task { await viewModel.performSearch() }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Text(historyItem)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(TTokens.spacingMD)
                    .background {
                        RoundedRectangle(cornerRadius: TTokens.radiusMD)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        }
    }
    
    private var popularSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("熱門搜索")
                .font(.headline.weight(.semibold))
            
            FlowLayout(spacing: TTokens.spacingSM) {
                ForEach(["團隊活動", "公司公告", "會議記錄", "專案進度", "考勤統計"], id: \.self) { tag in
                    Button {
                        viewModel.query = tag
                        Task { await viewModel.performSearch() }
                    } label: {
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, TTokens.spacingMD)
                            .padding(.vertical, TTokens.spacingSM)
                            .background {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Results View
    
    private func resultsView(_ results: SearchResults) -> some View {
        ScrollView {
            LazyVStack(spacing: TTokens.spacingMD) {
                // 文章結果
                if !results.posts.isEmpty {
                    resultSection(title: "文章 (\(results.posts.count))") {
                        ForEach(results.posts, id: \.id) { post in
                            SearchResultCard(
                                title: post.summary,
                                subtitle: post.content,
                                type: "文章",
                                icon: "doc.text.fill",
                                color: .tint
                            )
                        }
                    }
                }
                
                // 公告結果
                if !results.broadcasts.isEmpty {
                    resultSection(title: "公告 (\(results.broadcasts.count))") {
                        ForEach(results.broadcasts, id: \.id) { broadcast in
                            SearchResultCard(
                                title: broadcast.title,
                                subtitle: broadcast.body,
                                type: "公告",
                                icon: "megaphone.fill",
                                color: .warn
                            )
                        }
                    }
                }
                
                // 用戶結果
                if !results.users.isEmpty {
                    resultSection(title: "用戶 (\(results.users.count))") {
                        ForEach(results.users, id: \.id) { user in
                            SearchResultCard(
                                title: user.displayName,
                                subtitle: user.email ?? "無簡介",
                                type: "用戶",
                                icon: "person.fill",
                                color: .creative
                            )
                        }
                    }
                }
                
                // 活動結果
                if !results.events.isEmpty {
                    resultSection(title: "活動 (\(results.events.count))") {
                        ForEach(results.events, id: \.id) { event in
                            SearchResultCard(
                                title: event.title,
                                subtitle: event.description,
                                type: "活動",
                                icon: "calendar",
                                color: .success
                            )
                        }
                    }
                }
            }
            .padding(TTokens.spacingLG)
        }
    }
    
    private func resultSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text(title)
                .font(.headline.weight(.semibold))
            
            content()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: TTokens.spacingLG) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding(TTokens.spacingLG)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        AppEmptyStateView(
            systemImage: "magnifyingglass",
            title: "沒有找到結果",
            subtitle: "試試其他關鍵字"
        )
        .padding(.top, 100)
    }
}

// MARK: - Search Result Card

private struct SearchResultCard: View {
    let title: String
    let subtitle: String
    let type: String
    let icon: String
    let color: Color
    
    var body: some View {
        Button {
            HapticFeedback.light()
            // TODO: Navigate to detail
        } label: {
            HStack(spacing: TTokens.spacingMD) {
                ZStack {
                    RoundedRectangle(cornerRadius: TTokens.radiusSM)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(TTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: TTokens.radiusMD)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing }
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(indices: [Int], height: CGFloat)] {
        var rows: [(indices: [Int], height: CGFloat)] = []
        var currentRow: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append((currentRow, currentHeight))
                currentRow = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentRow.append(index)
                currentWidth += size.width + spacing
                currentHeight = max(currentHeight, size.height)
            }
        }
        
        if !currentRow.isEmpty {
            rows.append((currentRow, currentHeight))
        }
        
        return rows
    }
}
