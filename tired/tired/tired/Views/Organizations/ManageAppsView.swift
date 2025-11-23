import SwiftUI

@available(iOS 17.0, *)
struct ManageAppsView: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("可用的組織應用"), footer: Text("啟用或停用組織頁面中顯示的小應用。")) {
                    ForEach(OrgAppTemplateKey.allCases, id: \.self) { templateKey in
                        AppToggleRow(viewModel: viewModel, templateKey: templateKey)
                    }
                }
            }
            .navigationTitle("管理應用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
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
            HStack(spacing: 12) {
                Image(systemName: templateKey.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(templateKey.displayName)
                        .font(.system(size: 15, weight: .medium))
                    Text(templateKey.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Add helper properties to OrgAppTemplateKey for UI
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
