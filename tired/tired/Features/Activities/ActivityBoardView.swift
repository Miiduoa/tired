import SwiftUI
import Combine

@MainActor
final class ActivityBoardViewModel: ObservableObject {
    @Published private(set) var items: [ActivityListItem] = []
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        items = await service.activities(for: membership)
    }
}

struct ActivityBoardView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: ActivityBoardViewModel
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: ActivityBoardViewModel(membership: membership, service: service))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.items.sorted { $0.timestamp > $1.timestamp }) { item in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: item.kind))
                        .font(.title3)
                        .foregroundStyle(color(for: item.kind))
                        .frame(width: 28, height: 28)
                        .background(color(for: item.kind).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("活動")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
    
    private func icon(for kind: ActivityListItem.Kind) -> String {
        switch kind {
        case .broadcast: return "megaphone"
        case .rollcall: return "qrcode.viewfinder"
        case .clock: return "location"
        case .esg: return "leaf"
        }
    }
    
    private func color(for kind: ActivityListItem.Kind) -> Color {
        switch kind {
        case .broadcast: return .purple
        case .rollcall: return .orange
        case .clock: return .green
        case .esg: return .mint
        }
    }
}
