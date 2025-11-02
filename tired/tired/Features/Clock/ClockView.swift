import SwiftUI
import Combine

@MainActor
final class ClockViewModel: ObservableObject {
    @Published private(set) var records: [ClockRecordItem] = []
    @Published private(set) var isLoading = false
    
    private let service: TenantFeatureServiceProtocol
    private let membership: TenantMembership
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
    }
    
    func load() async {
        isLoading = true
        let items = await service.clockRecords(for: membership)
        records = items.sorted { $0.time > $1.time }
        isLoading = false
    }
    
    func insertLocalRecord(site: String, time: Date, status: ClockRecordItem.Status) {
        let item = ClockRecordItem(id: "local-\(UUID().uuidString)", site: site, time: time, status: status)
        records.insert(item, at: 0)
    }
}

struct ClockView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: ClockViewModel
    @State private var filter: ClockRecordItem.Status? = nil
    @EnvironmentObject private var authService: AuthService
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: ClockViewModel(membership: membership, service: service))
    }
    
    private var filteredRecords: [ClockRecordItem] {
        guard let filter else { return viewModel.records }
        return viewModel.records.filter { $0.status == filter }
    }
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.records.isEmpty {
                AppLoadingView(title: "同步中…")
            } else if filteredRecords.isEmpty {
                AppEmptyStateView(
                    systemImage: "mappin.and.ellipse",
                    title: "目前沒有打卡紀錄",
                    subtitle: "完成第一次打卡後會顯示在此"
                )
            } else {
                ForEach(filteredRecords) { record in
                    HStack(spacing: 12) {
                        Image(systemName: record.status == .ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(record.status == .ok ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.site)
                                .font(.body.weight(.medium))
                            Text(record.time, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.status == .ok ? "正常" : "異常")
                            .font(.caption)
                            .foregroundStyle(record.status == .ok ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("打卡紀錄")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("全部") { filter = nil }
                    Button("正常") { filter = .ok }
                    Button("異常") { filter = .exception }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    Haptics.impact(.rigid)
                    Task { await submitClock() }
                    Haptics.success()
                } label: {
                    Label("立即打卡", systemImage: "mappin.and.ellipse")
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .background(Color.bg.ignoresSafeArea())
    }

    private func submitClock() async {
        let siteId = membership.id // server側用站點ID；此處用群組ID作示範
        let siteName = membership.tenant.name
        let ts = Date()

        guard let uid = authService.currentUser?.id, !uid.isEmpty else {
            // 未登入：僅本地顯示
            withAnimation { viewModel.insertLocalRecord(site: siteName, time: ts, status: .ok) }
            return
        }
        let key = "clock-\(UUID().uuidString)"
        // 先入列以確保崩潰/離開也能補送
        OutboxService.shared.enqueueClockRecord(siteId: siteId, uid: uid, idempotencyKey: key, ts: ts)
        do {
            _ = try await ClockAPI.submit(siteId: siteId, uid: uid, idempotencyKey: key, ts: ts)
            OutboxService.shared.remove(id: "outbox-clock-\(siteId)-\(key)", for: uid)
        } catch {
            // 留給 outbox 重試
        }
        withAnimation { viewModel.insertLocalRecord(site: siteName, time: ts, status: .ok) }
    }
}
