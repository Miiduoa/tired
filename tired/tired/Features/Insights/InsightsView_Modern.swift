import SwiftUI
import Charts
import Combine

// MARK: - ViewModel

@MainActor
final class InsightsViewModelModern: ObservableObject {
    @Published private(set) var dashboardData: DashboardSummary?
    @Published private(set) var attendanceData: AttendanceAnalyticsData?
    @Published private(set) var activityData: ActivityEngagement?
    @Published private(set) var isLoading = false
    @Published var selectedPeriod: Period = .week
    
    private let membership: TenantMembership
    
    enum Period: String, CaseIterable {
        case week = "本週"
        case month = "本月"
        case quarter = "本季"
        case year = "本年"
        
        var apiValue: String {
            switch self {
            case .week: return "week"
            case .month: return "month"
            case .quarter: return "quarter"
            case .year: return "year"
            }
        }
    }
    
    init(membership: TenantMembership) {
        self.membership = membership
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let dashboardTask = InsightsAPI.getDashboardSummary(tenantId: membership.tenant.id)
            async let attendanceTask = InsightsAPI.getAttendanceAnalytics(tenantId: membership.tenant.id, period: selectedPeriod.apiValue)
            async let activityTask = InsightsAPI.getActivityEngagement(tenantId: membership.tenant.id, period: selectedPeriod.apiValue)
            
            dashboardData = try await dashboardTask
            attendanceData = try await attendanceTask
            activityData = try await activityTask
        } catch {
            print("⚠️ Failed to load insights: \(error)")
        }
    }
    
    func exportReport(format: String) async {
        do {
            let url = try await InsightsAPI.exportReport(tenantId: membership.tenant.id, reportType: "full", format: format)
            HapticFeedback.success()
            ToastCenter.shared.show("報表已生成", style: .success)
            print("📊 Report URL: \(url)")
        } catch {
            HapticFeedback.error()
            ToastCenter.shared.show("報表生成失敗", style: .error)
        }
    }
}

// MARK: - Main View

struct InsightsView_Modern: View {
    let membership: TenantMembership
    @StateObject private var viewModel: InsightsViewModelModern
    @State private var showExportSheet = false
    
    init(membership: TenantMembership) {
        self.membership = membership
        _viewModel = StateObject(wrappedValue: InsightsViewModelModern(membership: membership))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientMeshBackground()
                
                ScrollView {
                    if viewModel.isLoading && viewModel.dashboardData == nil {
                        loadingView
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("數據分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(InsightsViewModelModern.Period.allCases, id: \.self) { period in
                            Button(period.rawValue) {
                                viewModel.selectedPeriod = period
                                Task { await viewModel.load() }
                            }
                        }
                        
                        Divider()
                        
                        Button("導出報表", systemImage: "arrow.down.doc") {
                            showExportSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(TTokens.gradientPrimary)
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        LazyVStack(spacing: TTokens.spacingLG) {
            // 期間選擇器
            periodSelector
            
            // 儀表板摘要
            if let dashboard = viewModel.dashboardData {
                dashboardSection(dashboard)
            }
            
            // 出勤分析
            if let attendance = viewModel.attendanceData {
                attendanceSection(attendance)
            }
            
            // 活動參與
            if let activity = viewModel.activityData {
                activitySection(activity)
            }
        }
        .padding(TTokens.spacingLG)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: TTokens.spacingLG) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(height: 200)
            }
        }
        .padding(TTokens.spacingLG)
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        HStack(spacing: TTokens.spacingSM) {
            ForEach(InsightsViewModelModern.Period.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedPeriod = period
                    }
                    HapticFeedback.selection()
                    Task { await viewModel.load() }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.selectedPeriod == period ? .white : .secondary)
                        .padding(.horizontal, TTokens.spacingMD)
                        .padding(.vertical, TTokens.spacingSM)
                        .background {
                            if viewModel.selectedPeriod == period {
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
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Dashboard Section
    
    private func dashboardSection(_ dashboard: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HeroCard(
                title: "組織概覽",
                subtitle: "核心指標一覽",
                gradient: TTokens.gradientPrimary
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TTokens.spacingMD) {
                    StatCard(title: "總成員", value: "\(dashboard.totalMembers)", icon: "person.3.fill", color: .tint)
                    StatCard(title: "活躍度", value: "\(Int(dashboard.activeRate * 100))%", icon: "chart.line.uptrend.xyaxis", color: .success)
                    StatCard(title: "本週活動", value: "\(dashboard.weeklyEvents)", icon: "calendar", color: .creative)
                    StatCard(title: "平均出勤", value: "\(Int(dashboard.avgAttendanceRate * 100))%", icon: "checkmark.circle.fill", color: .warn)
                }
            }
        }
    }
    
    // MARK: - Attendance Section
    
    private func attendanceSection(_ attendance: AttendanceAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HeroCard(
                title: "出勤分析",
                subtitle: "\(viewModel.selectedPeriod.rawValue)統計",
                gradient: LinearGradient(colors: [.success, .tint], startPoint: .topLeading, endPoint: .bottomTrailing)
            ) {
                VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                    // 趨勢圖
                    if !attendance.dailyRates.isEmpty {
                        Chart(attendance.dailyRates) { dataPoint in
                            LineMark(
                                x: .value("日期", dataPoint.date),
                                y: .value("出勤率", dataPoint.rate)
                            )
                            .foregroundStyle(TTokens.gradientPrimary)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("日期", dataPoint.date),
                                y: .value("出勤率", dataPoint.rate)
                            )
                            .foregroundStyle(LinearGradient(
                                colors: [Color.success.opacity(0.3), Color.success.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 180)
                        .chartYScale(domain: 0...1)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let rate = value.as(Double.self) {
                                        Text("\(Int(rate * 100))%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 統計摘要
                    HStack(spacing: TTokens.spacingLG) {
                        miniStat(title: "平均", value: "\(Int(attendance.avgRate * 100))%", color: .success)
                        miniStat(title: "最高", value: "\(Int(attendance.maxRate * 100))%", color: .creative)
                        miniStat(title: "最低", value: "\(Int(attendance.minRate * 100))%", color: .warn)
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Section
    
    private func activitySection(_ activity: ActivityEngagement) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HeroCard(
                title: "活動參與",
                subtitle: "\(viewModel.selectedPeriod.rawValue)統計",
                gradient: LinearGradient(colors: [.creative, .warn], startPoint: .topLeading, endPoint: .bottomTrailing)
            ) {
                VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                    // 參與類型分布
                    if !activity.typeDistribution.isEmpty {
                        Chart(activity.typeDistribution) { item in
                            BarMark(
                                x: .value("類型", item.type),
                                y: .value("數量", item.count)
                            )
                            .foregroundStyle(by: .value("類型", item.type))
                        }
                        .frame(height: 150)
                        .chartForegroundStyleScale([
                            "活動": Color.creative,
                            "投票": Color.tint,
                            "公告": Color.warn
                        ])
                    }
                    
                    Divider()
                    
                    // Top 參與者
                    if !activity.topParticipants.isEmpty {
                        VStack(alignment: .leading, spacing: TTokens.spacingSM) {
                            Text("活躍成員 Top 5")
                                .font(.subheadline.weight(.semibold))
                            
                            ForEach(Array(activity.topParticipants.prefix(5).enumerated()), id: \.element.userId) { index, participant in
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(rankColor(index))
                                        .frame(width: 30)
                                    
                                    AvatarRing(size: 32, strokeWidth: 2, active: true)
                                    
                                    Text(participant.userName)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text("\(participant.count) 次")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Export Sheet
    
    private var exportSheet: some View {
        NavigationStack {
            List {
                Section("選擇格式") {
                    Button {
                        Task {
                            await viewModel.exportReport(format: "pdf")
                            showExportSheet = false
                        }
                    } label: {
                        Label("PDF 報表", systemImage: "doc.text.fill")
                    }
                    
                    Button {
                        Task {
                            await viewModel.exportReport(format: "excel")
                            showExportSheet = false
                        }
                    } label: {
                        Label("Excel 報表", systemImage: "tablecells")
                    }
                    
                    Button {
                        Task {
                            await viewModel.exportReport(format: "csv")
                            showExportSheet = false
                        }
                    } label: {
                        Label("CSV 數據", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("導出報表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showExportSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Views
    
    private func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: TTokens.spacingXS) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingSM) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(TTokens.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: TTokens.radiusMD)
                .fill(color.opacity(0.1))
        }
    }
}

