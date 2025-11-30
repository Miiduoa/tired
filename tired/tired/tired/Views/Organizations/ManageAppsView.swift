import SwiftUI

@available(iOS 17.0, *)
struct ManageAppsView: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

                Form {
                    Section {
                        ForEach(OrgAppTemplateKey.allCases, id: \.self) { templateKey in
                            AppToggleRow(viewModel: viewModel, templateKey: templateKey)
                                .listRowBackground(Color.clear) // Make row transparent
                        }
                    } header: {
                        Text("可用的組織應用")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    } footer: {
                        Text("啟用或停用組織頁面中顯示的小應用。")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: AppDesignSystem.paddingMedium, bottom: AppDesignSystem.paddingSmall, trailing: AppDesignSystem.paddingMedium))

                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("管理應用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .primary))
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct AppToggleRow: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    let templateKey: OrgAppTemplateKey
    @State private var isProcessing = false

    private var isEnabled: Binding<Bool> {
                Binding(
            get: { viewModel.allApps.contains { $0.templateKey == templateKey && $0.isEnabled } },
            set: { newValue in
                _Concurrency.Task {
                    guard !isProcessing else { return }
                    await MainActor.run { isProcessing = true }
                    if newValue {
                        let success = await viewModel.enableAppAsync(templateKey: templateKey)
                        if !success {
                            ToastManager.shared.showToast(message: "啟用應用失敗，請稍後再試。", type: .error)
                        }
                    } else {
                        // Find the app instance from allApps to disable it
                        if let app = viewModel.allApps.first(where: { $0.templateKey == templateKey }) {
                            let success = await viewModel.disableAppAsync(appInstance: app)
                            if !success {
                                ToastManager.shared.showToast(message: "停用應用失敗，請稍後再試。", type: .error)
                            }
                        }
                    }
                    // small debounce to allow state to propagate
                    try? await _Concurrency.Task.sleep(nanoseconds: 80_000_000)
                    await MainActor.run { isProcessing = false }
                }
            }
        )
    }

    var body: some View {
        Toggle(isOn: isEnabled) {
            HStack(spacing: AppDesignSystem.paddingMedium) {
                Image(systemName: templateKey.iconName)
                    .font(.title2)
                    .foregroundColor(AppDesignSystem.accentColor)
                    .frame(width: 36, height: 36)
                    .background(AppDesignSystem.accentColor.opacity(0.1))
                    .cornerRadius(AppDesignSystem.cornerRadiusSmall)

                VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                    Text(templateKey.displayName)
                        .font(AppDesignSystem.bodyFont.weight(.medium))
                        .foregroundColor(.primary)
                    Text(templateKey.description)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(isProcessing)
        .overlay(alignment: .trailing) {
            if isProcessing {
                ProgressView().scaleEffect(0.8).padding(.trailing, 8)
            }
        }
    }
}

// Add helper properties to OrgAppTemplateKey for UI (moved to DomainTypes.swift if it exists there)
// Temporarily re-adding here for compilation if not yet moved
extension OrgAppTemplateKey {
    var iconName: String {
        switch self {
        case .taskBoard: return "checklist"
        case .eventSignup: return "calendar.badge.plus"
        case .resourceList: return "folder"
        case .courseSchedule: return "calendar.circle"
        case .assignmentBoard: return "doc.text.fill"
        case .bulletinBoard: return "megaphone"
        case .rollCall: return "person.crop.circle.badge.checkmark"
        case .gradebook: return "chart.bar.doc.horizontal"
        }
    }

    var description: String {
        switch self {
        case .taskBoard: return "發布和管理組織任務"
        case .eventSignup: return "創建和報名組織活動"
        case .resourceList: return "分享文件、連結等資源"
        case .courseSchedule: return "查看和管理課程時間表"
        case .assignmentBoard: return "繳交作業與評分"
        case .bulletinBoard: return "發布重要通知與公告"
        case .rollCall: return "課堂點名與出席紀錄"
        case .gradebook: return "查看學期成績與評量"
        }
    }
}