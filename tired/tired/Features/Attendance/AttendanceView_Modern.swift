import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// 保留原有 ViewModel

struct AttendanceView_Modern: View {
    let membership: TenantMembership
    @StateObject private var viewModel: AttendanceViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var deepLink: DeepLinkRouter
    @State private var didLocalCheckIn = false
    @State private var enteredSessId = ""
    @State private var showScanner = false
    
    @MainActor
    init(membership: TenantMembership) {
        self.membership = membership
        let service = TenantFeatureService()
        _viewModel = StateObject(wrappedValue: AttendanceViewModel(membership: membership, service: service))
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
                        qrCard
                        statsGrid
                        recordsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("10秒點名")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            HapticFeedback.light()
                            showScanner = true
                        } label: {
                            Label("掃描學生 QR Code", systemImage: "qrcode.viewfinder")
                        }
                        
                        Button {
                            HapticFeedback.light()
                            viewModel.regenerateCode()
                        } label: {
                            Label("重新產生 QR Code", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .task(id: deepLink.pendingAttendanceSessId) {
                if let sess = deepLink.pendingAttendanceSessId, !sess.isEmpty {
                    await submitAttendanceCheck(using: sess)
                    deepLink.pendingAttendanceSessId = nil
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { code in
                    enteredSessId = code
                    showScanner = false
                    Task { await submitAttendanceCheck(using: code) }
                }
            }
        }
    }
    
    // MARK: - Hero 卡片
    
    private var heroCard: some View {
        HeroCard(
            title: membership.tenant.name,
            subtitle: "請確認裝置狀態正常後讓學生掃描 QR Code 完成點名",
            gradient: LinearGradient(colors: [.creative, .creative.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            HStack(spacing: TTokens.spacingMD) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("點名狀態")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(viewModel.snapshot != nil ? "進行中" : "準備中")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
        }
    }
    
    // MARK: - QR Code 卡片
    
    private var qrCard: some View {
        VStack(spacing: TTokens.spacingXL) {
            // QR Code 顯示
            ZStack {
                // 外圈呼吸光環
                RoundedRectangle(cornerRadius: 32)
                    .fill(TTokens.gradientCreative.opacity(0.1))
                    .frame(width: 280, height: 280)
                    .breathingCard(isActive: true)
                
                // QR Code
                if let image = generateQRCode(from: viewModel.qrSeed) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .background(.white)
                        .cornerRadius(24)
                        .shadow(color: .creative.opacity(0.3), radius: 20, y: 10)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.neutralLight.opacity(0.3))
                        .frame(width: 240, height: 240)
                        .overlay {
                            Text("無法產生 QR Code")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            
            // 倒數計時
            VStack(spacing: 8) {
                Text("剩餘時間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("\(viewModel.ttl)")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(TTokens.gradientCreative)
                        .monospacedDigit()
                    
                    Text("秒")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                // 進度條
                ProgressRing(
                    progress: Double(viewModel.ttl) / (Double(viewModel.snapshot?.validDuration ?? 30) * 60.0),
                    ringColor: .creative,
                    lineWidth: 4,
                    size: 100
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(TTokens.spacingXL)
        .floatingCard()
    }
    
    // MARK: - 統計網格
    
    @ViewBuilder
    private var statsGrid: some View {
        if let snapshot = viewModel.snapshot {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    value: "\(snapshot.stats.total)",
                    label: "總人數",
                    icon: "person.3.fill",
                    color: .tint
                )
                
                StatCard(
                    value: "\(snapshot.stats.attended)",
                    label: "已到",
                    icon: "checkmark.circle.fill",
                    color: .success
                )
                
                StatCard(
                    value: "\(snapshot.stats.absent)",
                    label: "缺席",
                    icon: "xmark.circle.fill",
                    color: .danger
                )
                
                StatCard(
                    value: "\(snapshot.stats.late)",
                    label: "遲到",
                    icon: "clock.fill",
                    color: .warn
                )
            }
        }
    }
    
    // MARK: - 記錄區
    
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("點名記錄")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
            
            if let snapshot = viewModel.snapshot, !snapshot.personalRecords.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(Array(snapshot.personalRecords.enumerated()), id: \.element.id) { index, record in
                        AttendanceRecordCard(record: record)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.98).combined(with: .opacity)
                            ))
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index % 10) * 0.04),
                                value: snapshot.personalRecords.count
                            )
                    }
                }
            } else {
                AppEmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "目前沒有記錄",
                    subtitle: "學生掃描 QR Code 後將顯示於此"
                )
            }
        }
    }
    
    // MARK: - QR Code 生成
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
    
    // MARK: - 提交點名
    
    private func submitAttendanceCheck(using sessionId: String) async {
        guard let uid = authService.currentUser?.id, !uid.isEmpty else {
            ToastCenter.shared.show("請先登入", style: .error)
            return
        }
        
        // TODO: 實現實際的 API 調用
        // try await AttendanceAPI.checkIn(userId: uid, sessionId: sessionId)
        didLocalCheckIn = true
        HapticFeedback.success()
        ToastCenter.shared.show("點名成功！", style: .success)
        await viewModel.load()
    }
}

// MARK: - 點名記錄卡片

private struct AttendanceRecordCard: View {
    let record: AttendanceRecord
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 狀態圖標
            AvatarRing(
                imageURL: nil,
                size: 50,
                ringColor: statusColor,
                ringWidth: 2
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(record.courseName)
                    .font(.subheadline.weight(.semibold))
                
                HStack(spacing: 8) {
                    Text(record.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text(record.status.title)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
            
            Spacer()
            
            // 狀態徽章
            Image(systemName: record.status.icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.15), in: Circle())
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
    
    private var statusColor: Color {
        switch record.status {
        case .present: return .success
        case .late: return .warn
        case .absent: return .danger
        }
    }
}

// MARK: - QR 掃描彈窗

private struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    
    var body: some View {
        NavigationStack {
            QRScannerView { result in
                switch result {
                case .success(let code):
                    onScan(code)
                case .failure:
                    dismiss()
                }
            }
            .ignoresSafeArea()
            .navigationTitle("掃描 QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 統計卡片

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: TTokens.spacingMD) {
            // 圖標
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            // 數值
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            
            // 標籤
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TTokens.spacingLG)
        .glassEffect(intensity: 0.7)
    }
}
