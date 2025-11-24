import SwiftUI

@available(iOS 17.0, *)
struct EditRoleView: View {
    @ObservedObject var viewModel: RoleManagementViewModel
    
    @State private var roleName: String
    @State private var permissions: Set<String>
    
    private let role: Role?
    private var isCreatingNewRole: Bool { role == nil }
    
    @Environment(\.dismiss) private var dismiss

    init(viewModel: RoleManagementViewModel, role: Role?) {
        self.viewModel = viewModel
        self.role = role
        
        // Initialize state based on whether we are editing or creating
        _roleName = State(initialValue: role?.name ?? "")
        _permissions = State(initialValue: Set(role?.permissions ?? []))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background

                Form {
                    Section {
                        TextField("例如：幹部、老師...", text: $roleName)
                            .textFieldStyle(FrostedTextFieldStyle())
                            .listRowBackground(Color.clear) // Make form row transparent
                    } header: {
                        Text("角色名稱")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))

                    Section {
                        ForEach(OrgPermission.allCases, id: \.self) { permission in
                            Toggle(isOn: Binding(
                                get: { self.permissions.contains(permission.rawValue) },
                                set: { isOn in
                                    if isOn {
                                        self.permissions.insert(permission.rawValue)
                                    } else {
                                        self.permissions.remove(permission.rawValue)
                                    }
                                }
                            )) {
                                Text(permission.displayName)
                                    .font(AppDesignSystem.bodyFont)
                                    .foregroundColor(.primary)
                            }
                            .tint(AppDesignSystem.accentColor) // Tint the toggle switch
                            .listRowBackground(Color.clear) // Make form row transparent
                        }
                    } header: {
                        Text("權限")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))

                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle(isCreatingNewRole ? "新增角色" : "編輯角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { saveAndDismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: AppDesignSystem.accentColor))
                        .disabled(roleName.isEmpty)
                }
            }
        }
    }
    
    private func saveAndDismiss() {
        _Concurrency.Task {
            if let role = role {
                // Editing existing role
                var updatedRole = role
                updatedRole.name = roleName
                updatedRole.permissions = Array(permissions)
                await viewModel.updateRole(updatedRole)
            } else {
                // Creating new role
                await viewModel.addRole(name: roleName, permissions: Array(permissions))
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
}