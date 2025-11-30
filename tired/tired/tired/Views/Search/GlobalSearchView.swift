import SwiftUI

@available(iOS 17.0, *)
struct GlobalSearchView: View {
    @StateObject private var viewModel = GlobalSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if viewModel.isLoading {
                        ProgressView("搜尋中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty {
                        ContentUnavailableView("找不到結果", systemImage: "magnifyingglass", description: Text("嘗試使用不同的關鍵字搜尋"))
                    } else if viewModel.searchText.isEmpty {
                        ContentUnavailableView("開始搜尋", systemImage: "magnifyingglass", description: Text("輸入關鍵字搜尋使用者、組織或任務"))
                    } else {
                        List {
                            // 1. Users Section
                            if let users = viewModel.searchResults[.user], !users.isEmpty {
                                SearchResultSection(title: "使用者", results: users)
                            }
                            
                            // 2. Organizations Section
                            if let orgs = viewModel.searchResults[.organization], !orgs.isEmpty {
                                SearchResultSection(title: "組織", results: orgs)
                            }
                            
                            // 3. Tasks Section
                            if let tasks = viewModel.searchResults[.task], !tasks.isEmpty {
                                SearchResultSection(title: "任務", results: tasks)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("搜尋")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋人員、組織、任務...")
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SearchResultSection: View {
    let title: String
    let results: [GlobalSearchResult]
    
    var icon: String {
        switch results.first?.type {
        case .user: return "person.circle.fill"
        case .organization: return "building.2.fill"
        case .task: return "checkmark.circle.fill"
        case .event: return "calendar"
        case .post: return "text.bubble.fill"
        case .none: return "questionmark"
        }
    }

    var body: some View {
        Section {
            ForEach(results) { result in
                NavigationLink(destination: destinationView(for: result)) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let snippet = result.snippet {
                                Text(snippet)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func destinationView(for result: GlobalSearchResult) -> some View {
        switch result.type {
        case .user:
            UserProfileView(userId: result.objectID)
        case .organization:
            OrganizationDetailView(organizationId: result.objectID)
        case .task:
            TaskDetailView(viewModel: TasksViewModel(), taskId: result.objectID)
        case .event:
            Text("活動詳情 (開發中)") // Placeholder
        case .post:
            Text("貼文詳情 (開發中)") // Placeholder
        }
    }
}
