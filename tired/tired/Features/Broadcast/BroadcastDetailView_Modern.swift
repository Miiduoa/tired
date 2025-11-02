import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class BroadcastDetailViewModel: ObservableObject {
    @Published private(set) var broadcast: BroadcastListItem
    @Published private(set) var ackStats: AckStats?
    @Published private(set) var isAcknowledging = false
    @Published private(set) var attachments: [AttachmentFile] = []
    
    private let membership: TenantMembership
    private let authService: AuthService
    
    init(broadcast: BroadcastListItem, membership: TenantMembership, authService: AuthService = AuthService.shared) {
        self.broadcast = broadcast
        self.membership = membership
        self.authService = authService
    }
    
    func load() async {
        do {
            // 獲取回條統計
            ackStats = try await BroadcastAPI.fetchAckStats(broadcastId: broadcast.id)
            
            // Mock attachments
            attachments = [
                AttachmentFile(id: "1", name: "考試範圍.pdf", size: 1024 * 256, type: .pdf),
                AttachmentFile(id: "2", name: "注意事項.jpg", size: 1024 * 128, type: .image)
            ]
        } catch {
            print("⚠️ Failed to load broadcast details: \(error)")
        }
    }
    
    func acknowledge() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isAcknowledging = true
        defer { isAcknowledging = false }
        
        do {
            try await BroadcastAPI.ack(broadcastId: broadcast.id, uid: userId, idempotencyKey: "ack-\(broadcast.id)-\(UUID().uuidString)")
            broadcast.acked = true
            HapticFeedback.success()
            ToastCenter.shared.show("已確認公告", style: .success)
            await load() // Reload stats
        } catch {
            HapticFeedback.error()
            ToastCenter.shared.show("確認失敗，請稍後再試", style: .error)
        }
    }
}

// MARK: - Main View

struct BroadcastDetailView_Modern: View {
    let broadcast: BroadcastListItem
    let membership: TenantMembership
    @StateObject private var viewModel: BroadcastDetailViewModel
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    init(broadcast: BroadcastListItem, membership: TenantMembership) {
        self.broadcast = broadcast
        self.membership = membership
        _viewModel = StateObject(wrappedValue: BroadcastDetailViewModel(broadcast: broadcast, membership: membership))
    }
    
    var body: some View {
        ZStack {
            GradientMeshBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                    // 標題卡片
                    titleCard
                    
                    // 內容卡片
                    contentCard
                    
                    // 附件區域
                    if !viewModel.attachments.isEmpty {
                        attachmentsSection
                    }
                    
                    // 回條統計
                    if let stats = viewModel.ackStats {
                        statsCard(stats)
                    }
                }
                .padding(TTokens.spacingLG)
            }
            .safeAreaInset(edge: .bottom) {
                if !viewModel.broadcast.acked {
                    bottomActionBar
                }
            }
        }
        .navigationTitle("公告詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("分享", systemImage: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    Button("複製內容", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = viewModel.broadcast.body
                        HapticFeedback.success()
                        ToastCenter.shared.show("已複製", style: .info)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await viewModel.load() }
    }
    
    // MARK: - Title Card
    
    private var titleCard: some View {
        HeroCard(
            title: viewModel.broadcast.title,
            subtitle: formatDate(viewModel.broadcast.deadline),
            gradient: viewModel.broadcast.requiresAck ?
                TTokens.gradientPrimary :
                LinearGradient(colors: [.secondary, .secondary.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            HStack(spacing: TTokens.spacingSM) {
                if viewModel.broadcast.requiresAck {
                    TagBadge(
                        viewModel.broadcast.acked ? "已確認" : "需回條",
                        color: viewModel.broadcast.acked ? .success : .warn
                    )
                }
                
                if let deadline = viewModel.broadcast.deadline {
                    let isUrgent = deadline.timeIntervalSinceNow < 86400 // 24 hours
                    if isUrgent && !viewModel.broadcast.acked {
                        TagBadge("緊急", color: .danger)
                    }
                }
            }
        }
    }
    
    // MARK: - Content Card
    
    private var contentCard: some View {
        GlassmorphicCard(tint: .tint) {
            VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                Text("內容")
                    .font(.headline.weight(.semibold))
                
                Text(viewModel.broadcast.body)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                
                if let deadline = viewModel.broadcast.deadline {
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Color.warn)
                        Text("截止時間：\(deadline.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Attachments Section
    
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text("附件 (\(viewModel.attachments.count))")
                .font(.headline.weight(.semibold))
            
            ForEach(viewModel.attachments) { attachment in
                attachmentRow(attachment)
            }
        }
    }
    
    private func attachmentRow(_ attachment: AttachmentFile) -> some View {
        Button {
            HapticFeedback.light()
            ToastCenter.shared.show("開始下載...", style: .info)
        } label: {
            HStack(spacing: TTokens.spacingMD) {
                // 文件圖標
                ZStack {
                    RoundedRectangle(cornerRadius: TTokens.radiusSM)
                        .fill(attachment.type.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: attachment.type.icon)
                        .font(.title3)
                        .foregroundStyle(attachment.type.color)
                }
                
                // 文件信息
                VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                    Text(attachment.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(formatFileSize(attachment.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 下載圖標
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.tint)
            }
            .padding(TTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: TTokens.radiusMD)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats Card
    
    private func statsCard(_ stats: AckStats) -> some View {
        GlassmorphicCard(tint: .tint) {
            VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                HStack {
                    Text("回條統計")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(Int(stats.ackRate * 100))% 已確認")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.success)
                }
                
                // 進度條
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(TTokens.gradientPrimary)
                            .frame(width: geo.size.width * stats.ackRate)
                    }
                }
                .frame(height: 12)
                
                // 統計數字
                HStack(spacing: TTokens.spacingLG) {
                    statItem(title: "總數", value: "\(stats.total)", color: .primary)
                    statItem(title: "已確認", value: "\(stats.acked)", color: .success)
                    statItem(title: "待確認", value: "\(stats.pending)", color: .warn)
                }
            }
        }
    }
    
    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: TTokens.spacingXS) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                Task { await viewModel.acknowledge() }
            } label: {
                Group {
                    if viewModel.isAcknowledging {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        HStack(spacing: TTokens.spacingSM) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("確認已知悉")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: TTokens.touchTargetComfortable)
            }
            .buttonStyle(FluidButtonStyle(gradient: TTokens.gradientPrimary))
            .disabled(viewModel.isAcknowledging)
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.vertical, TTokens.spacingMD)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "無截止時間" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "截止：\(formatter.string(from: date))"
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Data Models

struct AttachmentFile: Identifiable {
    let id: String
    let name: String
    let size: Int
    let type: FileType
    
    enum FileType {
        case pdf
        case image
        case document
        case other
        
        var icon: String {
            switch self {
            case .pdf: return "doc.text.fill"
            case .image: return "photo.fill"
            case .document: return "doc.fill"
            case .other: return "paperclip"
            }
        }
        
        var color: Color {
            switch self {
            case .pdf: return .red
            case .image: return .creative
            case .document: return .tint
            case .other: return .secondary
            }
        }
    }
}
