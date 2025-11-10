import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published private(set) var snapshot: AttendanceSnapshot?
    @Published private(set) var isLoading = false
    @Published var qrSeed: String = UUID().uuidString
    @Published private(set) var ttl: Int = 30
    @Published var currentSessionId: String? = nil
    
    private let membership: TenantMembership
    private let service: TenantFeatureServiceProtocol
    private let attendanceService = AttendanceService.shared
    private var timer: AnyCancellable?
    private var currentUserId: String?
    
    init(membership: TenantMembership, service: TenantFeatureServiceProtocol) {
        self.membership = membership
        self.service = service
        startTicker()
    }
    
    deinit {
        timer?.cancel()
    }
    
    func updateUserId(_ id: String?) {
        currentUserId = id
    }
    
    func load() async {
        isLoading = true
        let baseSnapshot = await service.attendanceSnapshot(for: membership)
        let merged = await attendanceService.mergedSnapshot(
            base: baseSnapshot,
            membership: membership,
            userId: currentUserId
        )
        if merged.personalRecords.isEmpty,
           let fallback = await attendanceService.localFallbackSnapshot(
                membership: membership,
                userId: currentUserId
            ) {
            self.snapshot = fallback
            ttl = fallback.validDuration * 60
        } else {
            self.snapshot = merged
            ttl = merged.validDuration * 60
        }
        isLoading = false
    }
    
    func regenerateCode() {
        if let currentSessionId { qrSeed = currentSessionId } else { qrSeed = UUID().uuidString }
        if let snapshot {
            ttl = snapshot.validDuration * 60
        } else {
            ttl = 30
        }
    }

    func appendPersonalRecord(_ record: AttendanceRecord) {
        if let snapshot {
            var records = snapshot.personalRecords
            records.insert(record, at: 0)
            records.sort { $0.date > $1.date }
            let stats = AttendanceStats(
                attended: snapshot.stats.attended + 1,
                absent: snapshot.stats.absent,
                late: snapshot.stats.late,
                total: max(snapshot.stats.total, snapshot.stats.attended + snapshot.stats.absent + snapshot.stats.late + 1)
            )
            let updated = AttendanceSnapshot(
                courseName: snapshot.courseName,
                attendanceTime: snapshot.attendanceTime,
                validDuration: snapshot.validDuration,
                stats: stats,
                personalRecords: records
            )
            self.snapshot = updated
            ttl = updated.validDuration * 60
        } else {
            let stats = AttendanceStats(attended: 1, absent: 0, late: 0, total: 1)
            let fallback = AttendanceSnapshot(
                courseName: membership.tenant.name,
                attendanceTime: Date(),
                validDuration: 30,
                stats: stats,
                personalRecords: [record]
            )
            snapshot = fallback
            ttl = fallback.validDuration * 60
        }
    }

    func updateTTL(seconds: Int) {
        ttl = max(0, seconds)
    }
    
    private func startTicker() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.ttl > 0 else {
                    self.regenerateCode()
                    return
                }
                self.ttl -= 1
            }
    }
}

struct AttendanceView: View {
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
                ScrollView {
            VStack(alignment: .leading, spacing: TTokens.spacingXL) {
                header
                qrSection
                statsSection
                recordsSection
            }
            .standardPadding()
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("10 秒點名")
        .task {
            viewModel.updateUserId(authService.currentUser?.id)
            await viewModel.load()
        }
        .refreshable {
            viewModel.updateUserId(authService.currentUser?.id)
            await viewModel.load()
        }
        .onChange(of: authService.currentUser?.id) { _, newValue in
            viewModel.updateUserId(newValue)
        }
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
                    case .failure:
                        showScanner = false
                    }
                }
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("關閉") { showScanner = false }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(membership.tenant.name)
                .font(.title2.weight(.semibold))
            Text("請確認裝置狀態正常後讓學生掃描 QR Code 完成點名。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var qrSection: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                AppLoadingView(title: "同步中…")
            } else {
                Image(uiImage: qrCode(from: viewModel.qrSeed))
                    .interpolation(.none)
                .resizable()
                .scaledToFit()
                    .frame(width: 240, height: 240)
                    .glassEffect(intensity: 0.7)
                    .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
                
                Text("QR Code 將在 \(viewModel.ttl) 秒後更新")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                if membership.role.isManagerial {
                    HStack(spacing: 12) {
                        Button("開始點名") {
                            Haptics.impact(.medium)
                            Task { await createAttendanceSession() }
                        }
                        .tPrimaryButton()
                        
                        Button("結束點名") {
                            Haptics.impact(.light)
                            Task { await closeAttendanceSession() }
                            ToastCenter.shared.show("已結束點名", style: .info)
                        }
                        .tSecondaryButton()
                    }
                } else {
                    VStack(spacing: 8) {
                        TextField("輸入課堂碼（掃描 QR 取得）", text: $enteredSessId)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Haptics.impact(.light)
                            showScanner = true
                        } label: {
                            Label("掃描 QR", systemImage: "qrcode.viewfinder")
                        }
                        .tSecondaryButton()
                        Button {
                            Haptics.impact(.medium)
                            Task { await submitAttendanceCheck(using: enteredSessId) }
                        } label: {
                            Label("我已到", systemImage: "hand.raised")
                        }
                        .tPrimaryButton(fullWidth: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .glassEffect(intensity: 0.7)
        .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
    }
    
    private var statsSection: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 12) {
                    Text("課程資訊")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        Label(snapshot.courseName, systemImage: "book.closed.fill")
                        Label("有效時間 \(snapshot.validDuration) 分鐘", systemImage: "timer")
                        Label("點名時間 \(snapshot.attendanceTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    
                    HStack(spacing: 12) {
                        AttendanceStatChip(title: "出席", value: snapshot.stats.attended, color: .green)
                        AttendanceStatChip(title: "缺席", value: snapshot.stats.absent, color: .red)
                        AttendanceStatChip(title: "遲到", value: snapshot.stats.late, color: .orange)
                        AttendanceStatChip(title: "總數", value: snapshot.stats.total, color: .blue)
                    }

                    if didLocalCheckIn {
                        Label("已送出簽到（可能等待同步）", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                .glassEffect(intensity: 0.7)
                .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
            }
        }
    }
    
    private var recordsSection: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最新紀錄")
                        .font(.headline)
                    if snapshot.personalRecords.isEmpty {
                        Text("尚無個人出勤歷史。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.personalRecords.prefix(5)) { record in
                            AttendanceRecordRow(record: record)
                        }
                    }
                }
                .glassEffect(intensity: 0.7)
                .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
            }
        }
    }
    
    private func qrCode(from string: String) -> UIImage {
        let context = Self.qrContext
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        if let output = filter.outputImage?.transformed(by: transform),
           let cgimg = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgimg)
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

private struct AttendanceStatChip: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.semibold))
            Text(title)
                .font(.caption)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
    }
}

private struct AttendanceRecordRow: View {
    let record: AttendanceRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.courseName)
                    .font(.subheadline.weight(.medium))
                Text(record.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.status.localizedTitle)
                .font(.caption.weight(.semibold))
                    .foregroundStyle(record.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(record.status.color.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 6)
    }
}

private extension AttendanceStatus {
    var localizedTitle: String {
        switch self {
        case .present: return "出席"
        case .absent: return "缺席"
        case .late: return "遲到"
        }
    }
}

private extension AttendanceView {
    static let qrContext = CIContext(options: [.useSoftwareRenderer: false])
}

extension AttendanceView {
    @MainActor
    private func submitAttendanceCheck(using sessIdRaw: String) async {
        let sessId = normalizeSessId(from: sessIdRaw)
        let uid = authService.currentUser?.id ?? "guest"
        let record = await AttendanceService.shared.checkIn(
            sessionId: sessId,
            membershipId: membership.id,
            userId: uid,
            courseName: viewModel.snapshot?.courseName ?? membership.tenant.name
        )
        viewModel.appendPersonalRecord(record)
        didLocalCheckIn = true
    }

    @MainActor
    private func createAttendanceSession() async {
        let courseId = membership.metadata["activeCourseId"] ?? "course-\(membership.id)"
        let teacherId = authService.currentUser?.id ?? "anonymous"
        let durationMinutes = viewModel.snapshot?.validDuration ?? 30
        let result = await AttendanceService.shared.openSession(
            membership: membership,
            courseId: courseId,
            teacherId: teacherId,
            durationMinutes: durationMinutes
        )
        viewModel.currentSessionId = result.record.id
        viewModel.qrSeed = result.record.qrSeed
        viewModel.updateTTL(seconds: result.ttlSeconds)
    }

    @MainActor
    private func closeAttendanceSession() async {
        guard let sessId = viewModel.currentSessionId else { return }
        let teacherId = authService.currentUser?.id ?? "anonymous"
        await AttendanceService.shared.closeSession(
            sessionId: sessId,
            membershipId: membership.id,
            teacherId: teacherId
        )
        viewModel.currentSessionId = nil
    }

    private func normalizeSessId(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "today-\(membership.id)" }
        // support deep link like tired://attendance?sessId=xxx or https://.../attendance?sessId=xxx
        if let url = URL(string: trimmed), let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let sess = comps.queryItems?.first(where: { $0.name.lowercased() == "sessid" })?.value, !sess.isEmpty {
                return sess
            }
            // path last segment fallback
            if let last = url.pathComponents.last, last.count > 3 { return last }
        }
        return trimmed
    }
}
