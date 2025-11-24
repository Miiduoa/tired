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

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { viewModel.allApps.contains { $0.templateKey == templateKey && $0.isEnabled } },
            set: { newValue in
                if newValue {
                    viewModel.enableApp(templateKey: templateKey)
                } else {
                    // Find the app instance from allApps to disable it
                    if let app = viewModel.allApps.first(where: { $0.templateKey == templateKey }) {
                        viewModel.disableApp(appInstance: app)
                    }
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
        }
    }

    var description: String {
        switch self {
        case .taskBoard: return "發布和管理組織任務"
        case .eventSignup: return "創建和報名組織活動"
        case .resourceList: return "分享文件、連結等資源"
        }
    }
}