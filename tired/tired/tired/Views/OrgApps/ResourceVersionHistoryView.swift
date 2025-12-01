import SwiftUI
import FirebaseAuth

/// 資源版本歷史視圖 - Moodle 風格的版本管理
@available(iOS 17.0, *)
struct ResourceVersionHistoryView: View {
    let resource: Resource
    let organizationId: String

    @StateObject private var viewModel = ResourceVersionHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestoreConfirmation = false
    @State private var versionToRestore: Resource?

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("載入版本歷史...")
                } else if viewModel.versions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            // 當前版本卡片
                            currentVersionCard

                            // 版本歷史列表
                            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                                Text("版本歷史")
                                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, AppDesignSystem.paddingMedium)

                                ForEach(Array(viewModel.versions.enumerated()), id: \.element.id) { index, version in
                                    VersionRow(
                                        version: version,
                                        isCurrent: index == 0,
                                        onRestore: {
                                            versionToRestore = version
                                            showingRestoreConfirmation = true
                                        },
                                        onDownload: {
                                            downloadVersion(version)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                        .padding(.vertical, AppDesignSystem.paddingLarge)
                    }
                }
            }
            .navigationTitle("版本歷史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("恢復版本", isPresented: $showingRestoreConfirmation) {
                Button("取消", role: .cancel) { }
                Button("恢復", role: .destructive) {
                    if let version = versionToRestore {
                        restoreVersion(version)
                    }
                }
            } message: {
                if let version = versionToRestore {
                    Text("確定要恢復到版本 \(version.version) 嗎？這將創建一個新版本並保留歷史記錄。")
                }
            }
            .onAppear {
                viewModel.loadVersionHistory(resourceId: resource.id ?? "", organizationId: organizationId)
            }
        }
    }

    // MARK: - Subviews

    private var currentVersionCard: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("當前版本")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)

                    Text("版本 \(resource.version)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppDesignSystem.accentColor)
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                if let fileName = resource.fileName {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.secondary)
                        Text(fileName)
                            .font(AppDesignSystem.bodyFont)
                    }
                }

                if let fileSize = resource.fileSize {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.secondary)
                        Text(formatFileSize(fileSize))
                            .font(AppDesignSystem.bodyFont)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text("更新於 \(resource.updatedAt.formatLong())")
                        .font(AppDesignSystem.bodyFont)
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("無版本歷史")
                .font(AppDesignSystem.titleFont)
                .foregroundColor(.primary)

            Text("這是第一個版本的資源")
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppDesignSystem.paddingLarge)
    }

    // MARK: - Actions

    private func restoreVersion(_ version: Resource) {
        Task {
            await viewModel.restoreVersion(version, currentResource: resource, organizationId: organizationId)
        }
    }

    private func downloadVersion(_ version: Resource) {
        guard let fileUrl = version.fileUrl ?? version.url else {
            ToastManager.shared.showToast(message: "無法下載此版本", type: .warning)
            return
        }

        // TODO: 實現下載功能
        print("📥 Download version \(version.version): \(fileUrl)")
        ToastManager.shared.showToast(message: "開始下載版本 \(version.version)", type: .info)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Version Row

@available(iOS 17.0, *)
struct VersionRow: View {
    let version: Resource
    let isCurrent: Bool
    let onRestore: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // 版本號指示器
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? AppDesignSystem.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 40)

                    Text("v\(version.version)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isCurrent ? .white : .secondary)
                }

                if isCurrent {
                    Text("當前")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppDesignSystem.accentColor)
                }
            }

            // 版本資訊
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(version.title)
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()
                }

                if let fileName = version.fileName {
                    Text(fileName)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if let fileSize = version.fileSize {
                        Label(formatFileSize(fileSize), systemImage: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Label(version.updatedAt.formatShort(), systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作按鈕
            HStack(spacing: 8) {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                if !isCurrent {
                    Button(action: onRestore) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - View Model

@MainActor
class ResourceVersionHistoryViewModel: ObservableObject {
    @Published var versions: [Resource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirebaseManager.shared.db

    func loadVersionHistory(resourceId: String, organizationId: String) {
        isLoading = true

        Task {
            do {
                // 獲取當前資源及其所有歷史版本
                var allVersions: [Resource] = []
                var currentId: String? = resourceId

                // 遞歸獲取所有版本（通過 previousVersionId 連結）
                while let id = currentId {
                    let doc = try await db.collection("resources")
                        .document(id)
                        .getDocument()

                    if let resource = try? doc.data(as: Resource.self) {
                        allVersions.append(resource)
                        currentId = resource.previousVersionId
                    } else {
                        break
                    }
                }

                // 按版本號排序（最新的在前）
                versions = allVersions.sorted { $0.version > $1.version }
                isLoading = false
            } catch {
                errorMessage = "載入版本歷史失敗：\(error.localizedDescription)"
                isLoading = false
                print("❌ Error loading version history: \(error)")
            }
        }
    }

    func restoreVersion(_ version: Resource, currentResource: Resource, organizationId: String) async {
        do {
            // 創建新版本（基於舊版本的內容）
            var restoredResource = version
            restoredResource.id = nil // 創建新文檔
            restoredResource.version = currentResource.version + 1
            restoredResource.previousVersionId = currentResource.id
            restoredResource.createdAt = Date()
            restoredResource.updatedAt = Date()
            restoredResource.title = "\(version.title) (從版本 \(version.version) 恢復)"

            // 保存新版本
            let docRef = try db.collection("resources").addDocument(from: restoredResource)

            await MainActor.run {
                ToastManager.shared.showToast(message: "已恢復到版本 \(version.version)", type: .success)
            }

            // 重新載入版本歷史
            loadVersionHistory(resourceId: docRef.documentID, organizationId: organizationId)
        } catch {
            await MainActor.run {
                errorMessage = "恢復版本失敗：\(error.localizedDescription)"
                ToastManager.shared.showToast(message: "恢復失敗：\(error.localizedDescription)", type: .error)
            }
            print("❌ Error restoring version: \(error)")
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct ResourceVersionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ResourceVersionHistoryView(
            resource: Resource(
                orgAppInstanceId: "test",
                organizationId: "test-org",
                title: "測試文件.pdf",
                type: .document,
                fileName: "測試文件.pdf",
                fileSize: 2048000,
                version: 3,
                previousVersionId: "prev-id",
                createdByUserId: "test-user"
            ),
            organizationId: "test-org"
        )
    }
}
