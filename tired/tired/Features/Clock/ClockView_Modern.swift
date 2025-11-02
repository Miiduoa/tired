import SwiftUI
import Combine

// 保留原有 ViewModel

struct ClockView_Modern: View {
    let membership: TenantMembership
    @StateObject private var viewModel: ClockViewModel
    @State private var filter: ClockRecordItem.Status? = nil
    @State private var showClockSheet = false
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
        NavigationStack {
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.records.isEmpty {
                    loadingView
                } else if filteredRecords.isEmpty {
                    emptyView
                } else {
                    recordsList
                }
                
                // 浮動打卡按鈕（大按鈕 + 呼吸動畫）
                VStack {
                    Spacer()
                    clockButton
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("打卡紀錄")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showClockSheet) {
                ClockInSheet(
                    onSubmit: { site in
                        await submitClock(site: site)
                    }
                )
            }
        }
    }
    
    // MARK: - 加載視圖
    
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    SkeletonCard()
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - 空狀態
    
    private var emptyView: some View {
        VStack(spacing: TTokens.spacingXL) {
            Spacer()
            
            AppEmptyStateView(
                systemImage: "mappin.and.ellipse",
                title: "目前沒有打卡紀錄",
                subtitle: "點擊下方按鈕完成第一次打卡"
            )
            
            Spacer()
        }
    }
    
    // MARK: - 記錄列表
    
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(filteredRecords.enumerated()), id: \.element.id) { index, record in
                    ClockRecordCard(record: record)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index % 10) * 0.04),
                            value: filteredRecords.count
                        )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 100) // 為浮動按鈕留空間
        }
    }
    
    // MARK: - 篩選菜單
    
    private var filterMenu: some View {
        Menu {
            Button {
                HapticFeedback.selection()
                filter = nil
            } label: {
                Label("全部", systemImage: filter == nil ? "checkmark" : "")
            }
            
            Button {
                HapticFeedback.selection()
                filter = .ok
            } label: {
                Label("正常", systemImage: filter == .ok ? "checkmark" : "")
            }
            
            Button {
                HapticFeedback.selection()
                filter = .exception
            } label: {
                Label("異常", systemImage: filter == .exception ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
    
    // MARK: - 打卡按鈕（超大 + 呼吸動畫）
    
    private var clockButton: some View {
        Button {
            HapticFeedback.heavy()
            showClockSheet = true
        } label: {
            HStack(spacing: TTokens.spacingMD) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2.weight(.semibold))
                Text("立即打卡")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(width: 200, height: TTokens.touchTargetLarge)
            .background {
                Capsule()
                    .fill(TTokens.gradientPrimary)
            }
            .shadow(color: .tint.opacity(0.4), radius: 20, y: 10)
        }
        .breathingCard(isActive: true)
    }
    
    // MARK: - 提交打卡
    
    private func submitClock(site: String) async {
        let userId = authService.currentUser?.id
        let record = await ClockService.shared.recordClock(
            for: membership,
            siteName: site,
            userId: userId
        )
        viewModel.prepend(record)
        HapticFeedback.success()
        let message = (userId == nil || userId?.isEmpty == true) ? "打卡成功（離線模式）" : "打卡成功！"
        ToastCenter.shared.show(message, style: .success)
    }
}

// MARK: - 打卡記錄卡片

private struct ClockRecordCard: View {
    let record: ClockRecordItem
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 狀態圖標
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(record.site)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.labelPrimary)
                
                HStack(spacing: 8) {
                    Text(record.time, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text(record.time, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 狀態徽章
            TagBadge(
                statusText,
                color: statusColor,
                icon: statusIcon
            )
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
    
    private var statusColor: Color {
        record.status == .ok ? .success : .warn
    }
    
    private var statusIcon: String {
        record.status == .ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    private var statusText: String {
        record.status == .ok ? "正常" : "異常"
    }
}

// MARK: - 打卡彈窗

private struct ClockInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var site: String = ""
    let onSubmit: (String) async -> Void
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: TTokens.spacingXL) {
                    Spacer()
                    
                    // 圖標
                    ZStack {
                        Circle()
                            .fill(TTokens.gradientPrimary.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 50))
                            .foregroundStyle(TTokens.gradientPrimary)
                    }
                    .shadow(color: .tint.opacity(0.3), radius: 20, y: 10)
                    
                    // 表單
                    VStack(spacing: TTokens.spacingLG) {
                        ModernFormField(
                            title: "打卡地點",
                            placeholder: "請輸入地點名稱",
                            text: $site,
                            icon: "location.fill"
                        )
                        
                        Button {
                            HapticFeedback.medium()
                            Task {
                                isSubmitting = true
                                await onSubmit(site)
                                isSubmitting = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("確認打卡")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: TTokens.touchTargetComfortable)
                        }
                        .fluidButton(gradient: canSubmit ? TTokens.gradientPrimary : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding(TTokens.spacingLG)
                    
                    Spacer()
                }
            }
            .navigationTitle("打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        !site.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
