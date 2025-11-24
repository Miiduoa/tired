import SwiftUI

@available(iOS 17.0, *)
struct RoleManagementView: View {
    @StateObject private var viewModel: RoleManagementViewModel

    init(organization: Organization) {
        _viewModel = StateObject(wrappedValue: RoleManagementViewModel(organization: organization))
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background
            navigationContent
        }
    }
    
    private var navigationContent: some View {
        NavigationView {
            List {
                rolesSection
            }
            .listStyle(.insetGrouped) // Use inset grouped to make sections glassmorphic
            .navigationTitle("角色管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: EditRoleView(viewModel: viewModel, role: nil)) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(AppDesignSystem.accentColor)
                    }
                }
            }
            .background(Color.clear) // Make NavigationView's background clear
        }
    }
    
    private var rolesSection: some View {
        Section {
            ForEach(viewModel.roles) { role in
                roleRow(role: role)
            }
            .onDelete(perform: deleteRole)
        } header: {
            Text("組織角色")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        } footer: {
            Text("點擊角色可進行編輯，或左滑刪除非預設的角色。")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        }
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial) // Apply glassmorphic to section
    }
    
    private func roleRow(role: Role) -> some View {
        NavigationLink(destination: EditRoleView(viewModel: viewModel, role: role)) {
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                Text(role.name)
                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    if role.isDefault == true {
                        Text("預設角色")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    Text("\(role.permissions.count) 項權限")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, AppDesignSystem.paddingSmall)
        }
        .listRowBackground(Color.clear) // Make form row transparent
    }

    private func deleteRole(at offsets: IndexSet) {
        let rolesToDelete = offsets.map { viewModel.roles[$0] }
        _Concurrency.Task {
            for role in rolesToDelete {
                if role.isDefault != true {
                    await viewModel.deleteRole(role)
                } else {
                    // Optionally, show an alert to the user that default roles cannot be deleted
                    print("Attempted to delete a default role: \(role.name)")
                }
            }
        }
    }
}