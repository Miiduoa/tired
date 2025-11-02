import SwiftUI
import Combine

// 保留原有 ViewModel

struct ESGOverviewView_Modern: View {
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
        NavigationStack {
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TTokens.spacingXL) {
                        heroCard
                        progressCard
                        reductionCard
                        recordsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("ESG 碳排管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            HapticFeedback.light()
                            // TODO: 上傳數據
                        } label: {
                            Label("上傳數據", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            HapticFeedback.light()
                            // TODO: 查看報表
                        } label: {
                            Label("查看報表", systemImage: "chart.bar.doc.horizontal")
                        }
                        
                        Button {
                            HapticFeedback.light()
                            // TODO: 設定目標
                        } label: {
                            Label("設定目標", systemImage: "target")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
    
    // MARK: - Hero 卡片
    
    private var heroCard: some View {
        HeroCard(
            title: "ESG 永續發展",
            subtitle: "實時追蹤碳排放量，共同邁向淨零目標",
            gradient: LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            HStack(spacing: TTokens.spacingMD) {
                Image(systemName: "leaf.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // 時間範圍選擇器
                Picker("", selection: $selectedRange) {
                    Text("本週").tag(0)
                    Text("本月").tag(1)
                    Text("本季").tag(2)
                }
                .pickerStyle(.segmented)
                .background(.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 進度卡片
    
    private var progressCard: some View {
        VStack(spacing: TTokens.spacingXL) {
            // 大進度環
            ZStack {
                Circle()
                    .stroke(Color.mint.opacity(0.2), lineWidth: 16)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        TTokens.gradientMint,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1, dampingFraction: 0.8), value: progressValue)
                
                VStack(spacing: 4) {
                    Text(progress)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(TTokens.gradientMint)
                    
                    Text("目標完成度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("請持續更新節能措施與證據")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(TTokens.spacingXL)
        .floatingCard()
    }
    
    // MARK: - 減排卡片
    
    private var reductionCard: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingLG) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("相較上期")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: isReduction ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(isReduction ? Color.success : Color.danger)
                        
                        Text(monthlyReduction)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(isReduction ? Color.success : Color.danger)
                    }
                }
                
                Spacer()
                
                // 趨勢圖標
                ZStack {
                    Circle()
                        .fill((isReduction ? Color.success : .danger).opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(isReduction ? .success : .danger)
                }
            }
            
            Divider()
            
            // 熱區分析
            VStack(alignment: .leading, spacing: 8) {
                Text("減碳熱區")
                    .font(.subheadline.weight(.semibold))
                
                HStack(spacing: 8) {
                    HotspotTag(label: "辦公室照明", percentage: "-18%")
                    HotspotTag(label: "伺服器待命", percentage: "-9%")
                }
            }
        }
        .padding(TTokens.spacingXL)
        .glassEffect(intensity: 0.8)
    }
    
    // MARK: - 記錄區
    
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("近期紀錄")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
            
            if viewModel.isLoading && viewModel.summary == nil {
                loadingView
            } else if let records = viewModel.summary?.records, !records.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(Array(records.sorted { $0.timestamp > $1.timestamp }.enumerated()), id: \.element.id) { index, record in
                        ESGRecordCard(record: record)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.98).combined(with: .opacity)
                            ))
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index % 10) * 0.04),
                                value: records.count
                            )
                    }
                }
            } else {
                AppEmptyStateView(
                    systemImage: "leaf.fill",
                    title: "沒有 ESG 紀錄",
                    subtitle: "請上傳或同步本期資料"
                )
            }
        }
    }
    
    private var loadingView: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                SkeletonCard()
                    .transition(.scale.combined(with: .opacity))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.08),
                        value: viewModel.isLoading
                    )
            }
        }
    }
    
    // MARK: - 計算屬性
    
    private var progressValue: Double {
        let numericString = progress.replacingOccurrences(of: "%", with: "")
        return (Double(numericString) ?? 0) / 100.0
    }
    
    private var isReduction: Bool {
        monthlyReduction.contains("-")
    }
}

// MARK: - ESG 記錄卡片

private struct ESGRecordCard: View {
    let record: ESGRecordItem
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 圖標
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(.mint)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(record.title)
                    .font(.subheadline.weight(.semibold))
                
                Text(record.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 時間
            Text(record.timestamp, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}

// MARK: - 熱區標籤

private struct HotspotTag: View {
    let label: String
    let percentage: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
            
            Text(percentage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.success)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.mint.opacity(0.15), in: Capsule())
    }
}

