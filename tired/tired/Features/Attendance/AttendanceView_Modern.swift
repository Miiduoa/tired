import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// 使用原有的 ViewModel
// 注意：將原文件中的 ViewModel 代碼保留

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
                    LazyVStack(spacing: TTokens.spacingXL) {
                        // 英雄卡片（QR 碼區域）
                        qrHeroCard
                        
                        // 統計儀表板
                        if let snapshot = viewModel.snapshot {
                            statsGrid(snapshot: snapshot)
                        }
                        
                        // 出席記錄
                        if let snapshot = viewModel.snapshot {
                            attendanceRecords(snapshot: snapshot)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("10 秒點名")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
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
                NavigationStack {
                    QRScannerView { result in
                        switch result {
                        case .success(let code):
                            enteredSessId = code
                            showScanner = false
                            Task { await submitAttendanceCheck(using: code) }
                        case .failure(let error):
                            ToastCenter.shared.show("掃描失敗: \(error.localizedDescription)", style: .error)
                        }
                    }
                    .navigationTitle("掃描 QR Code")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                HapticFeedback.selection()
                                showScanner = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - QR 英雄卡片
    
    private var qrHeroCard: some View {
        HeroCard(
            title: "出席 QR Code",
            subtitle: "有效時間：\(viewModel.ttl) 秒",
            gradient: TTokens.gradientPrimary
        ) {
            VStack(spacing: TTokens.spacingLG) {
                // QR 碼（玻璃框 + 呼吸動畫）
                ZStack {
                    RoundedRectangle(cornerRadius: TTokens.radiusXL, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: TTokens.radiusXL, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                    
                    if let qrImage = generateQR(from: viewModel.qrSeed) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 200, height: 200)
                            .padding(20)
                    }
                }
                .frame(width: 240, height: 240)
                .breathingCard(isActive: viewModel.ttl > 0)
                
                // 倒計時環
                ZStack {
                    Circle()
                        .stroke(Color.neutralLight, lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.ttl) / 30.0)
                        .stroke(
                            viewModel.ttl > 10 ? TTokens.gradientSuccess : TTokens.gradientWarm,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.ttl)
                    
                    Text("\(viewModel.ttl)s")
                        .font(.title.weight(.bold))
                        .foregroundStyle(viewModel.ttl > 10 ? .success : .warn)
                }
                .frame(width: 80, height: 80)
                
                // 重新生成按鈕
                Button {
                    HapticFeedback.medium()
                    viewModel.regenerateCode()
                    HapticFeedback.success()
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(height: TTokens.touchTargetComfortable)
                }
                .fluidButton(gradient: TTokens.gradientPrimary)
            }
        }
    }
    
    // MARK: - 統計網格
    
    private func statsGrid(snapshot: AttendanceSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: TTokens.spacingMD) {
            StatCard(
                value: "\(snapshot.presentCount)",
                label: "已出席",
                icon: "checkmark.circle.fill",
                color: .success
            )
            
            StatCard(
                value: "\(snapshot.absentCount)",
                label: "缺席",
                icon: "xmark.circle.fill",
                color: .danger
            )
            
            StatCard(
                value: "\(Int((Double(snapshot.presentCount) / Double(max(snapshot.presentCount + snapshot.absentCount, 1))) * 100))%",
                label: "出席率",
                icon: "chart.pie.fill",
                color: .tint
            )
            
            StatCard(
                value: "\(snapshot.presentCount + snapshot.absentCount)",
                label: "總人數",
                icon: "person.2.fill",
                color: .creative
            )
        }
    }
    
    // MARK: - 出席記錄
    
    private func attendanceRecords(snapshot: AttendanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("出席名單")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(snapshot.records.enumerated()), id: \.element.userId) { index, record in
                    attendanceRow(record: record, index: index)
                }
            }
        }
    }
    
    private func attendanceRow(record: AttendanceRecord, index: Int) -> some View {
        HStack(spacing: TTokens.spacingMD) {
            // 頭像環
            AvatarRing(
                imageURL: nil,
                size: 44,
                ringColor: record.present ? .success : .danger,
                ringWidth: 2
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(record.userName)
                    .font(.subheadline.weight(.semibold))
                
                if let time = record.checkInTime {
                    Text(time, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 狀態徽章
            if record.present {
                TagBadge("已出席", color: .success, icon: "checkmark.circle.fill")
            } else {
                TagBadge("缺席", color: .danger, icon: "xmark.circle.fill")
            }
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        ))
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8)
                .delay(Double(index % 10) * 0.04),
            value: snapshot?.records.count ?? 0
        )
    }
    
    // MARK: - 統計卡片組件
    
    private struct StatCard: View {
        let value: String
        let label: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(spacing: TTokens.spacingSM) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Spacer()
                }
                
                Text(value)
                    .font(.title.weight(.bold))
                    .foregroundStyle(color.gradient)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(TTokens.spacingLG)
            .floatingCard()
        }
    }
    
    // MARK: - QR 生成
    
    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Submit
    
    private func submitAttendanceCheck(using sessId: String) async {
        guard let uid = authService.currentUser?.id, !uid.isEmpty else {
            didLocalCheckIn = true
            ToastCenter.shared.show("打卡成功（離線模式）", style: .success)
            return
        }
        
        do {
            try await AttendanceAPI.checkIn(sessionId: sessId, uid: uid, idempotencyKey: "att-\(UUID().uuidString)")
            didLocalCheckIn = true
            HapticFeedback.success()
            ToastCenter.shared.show("簽到成功！", style: .success)
            await viewModel.load()
        } catch {
            HapticFeedback.error()
            ToastCenter.shared.show("簽到失敗：\(error.localizedDescription)", style: .error)
        }
    }
}

// 統一卡片組件
private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: TTokens.spacingSM) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(color.gradient)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}

