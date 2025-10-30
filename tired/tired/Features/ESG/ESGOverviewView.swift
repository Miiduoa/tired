import SwiftUI
import Combine

@MainActor
final class ESGOverviewViewModel: ObservableObject {
    @Published private(set) var summary: ESGSummary?
    @Published private(set) var isLoading = false
    
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        isLoading = true
        summary = await service.esgSummary(for: membership)
        isLoading = false
    }
}

struct ESGOverviewView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: ESGOverviewViewModel
    @State private var selectedRange = 0
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: ESGOverviewViewModel(membership: membership, service: service))
    }
    
    private var progress: String {
        viewModel.summary?.progress ?? membership.metadata["esg.progress"] ?? "82%"
    }
    
    private var monthlyReduction: String {
        viewModel.summary?.monthlyReduction ?? membership.metadata["esg.monthlyReduction"] ?? "-12%"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewCard
                reductionCard
                Divider()
                recordsSection
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("ESG")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("碳排挑戰進度")
                    .font(.headline)
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            Text(progress)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.mint)
            Text("目標完成度，請持續更新節能措施與證據。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $selectedRange) {
                Text("本週").tag(0)
                Text("本月").tag(1)
                Text("本季").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var reductionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相較上期")
                .font(.headline)
            Text(monthlyReduction)
                .font(.largeTitle.bold())
                .foregroundStyle(monthlyReduction.contains("-") ? Color.green : Color.red)
            Text("減碳熱區：辦公室照明 (-18%)、伺服器待命 (-9%)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("近期紀錄")
                .font(.headline)
            if viewModel.isLoading && viewModel.summary == nil {
                ProgressView("讀取中…")
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
            } else if let records = viewModel.summary?.records, !records.isEmpty {
                ForEach(records.sorted { $0.timestamp > $1.timestamp }) { record in
                    ESGRecordRow(record: record)
                }
            } else {
                Text("尚未有 ESG 相關紀錄，請上傳本期資料。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ESGRecordRow: View {
    let record: ESGRecordItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(.mint)
                .frame(width: 36, height: 36)
                .background(Color.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.subheadline.weight(.medium))
                Text(record.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.timestamp, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
