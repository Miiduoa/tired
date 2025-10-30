import SwiftUI
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var sections: [InsightSection] = []
    @Published private(set) var isLoading = false
    
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        isLoading = true
        sections = await service.insights(for: membership)
        isLoading = false
    }
}

struct InsightsView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: InsightsViewModel
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: InsightsViewModel(membership: membership, service: service))
    }
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("同步中…")
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                }
            } else if viewModel.sections.isEmpty {
                Section {
                    Text("尚未有分析資料。請稍後再試或至後台確認。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(viewModel.sections) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            insightRow(entry: entry)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分析")
        .background(Color.bg.ignoresSafeArea())
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
    
    private func insightRow(entry: InsightEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.subheadline.weight(.medium))
            Text(entry.value)
                .font(.title3.weight(.semibold))
            Text(entry.trend)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
