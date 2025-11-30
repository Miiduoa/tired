import SwiftUI

@available(iOS 17.0, *)
struct EditMemberRolesView: View {
    let member: MemberWithProfile
    let organization: Organization
    let onSave: ([String], String?) -> Void
    
    @State private var selectedRoleIds: Set<String>
    @State private var memberTitle: String
    @Environment(\.dismiss) private var dismiss

    init(member: MemberWithProfile, organization: Organization, onSave: @escaping ([String], String?) -> Void) {
        self.member = member
        self.organization = organization
        self.onSave = onSave
        _selectedRoleIds = State(initialValue: Set(member.membership.roleIds))
        _memberTitle = State(initialValue: member.membership.title ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background

                Form {
                    Section {
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                            Text("成員：\(member.displayName)")
                                .font(AppDesignSystem.headlineFont)
                                .foregroundColor(.primary)
                            Text("組織：\(organization.name)")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("成員資訊")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))
                    
                    Section {
                        TextField("例如：大二資管系、晚班工讀生", text: $memberTitle)
                            .textFieldStyle(StandardTextFieldStyle(icon: "person.text.rectangle"))
                    } header: {
                        Text("成員頭銜（選填）")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    } footer: {
                        Text("頭銜用於在組織中顯示成員的職位或身份，例如「大二資管系」、「晚班工讀生」等。")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))


                    Section {
                        // Sort roles to show default roles first
                        let sortedRoles = organization.roles.sorted { (r1, r2) -> Bool in
                            if r1.isDefault == true && r2.isDefault != true { return true }
                            if r1.isDefault != true && r2.isDefault == true { return false }
                            return r1.name < r2.name
                        }
                        
                        ForEach(sortedRoles) { role in
                            roleRow(for: role)
                                .listRowBackground(Color.clear) // Make row background transparent
                        }
                    } header: {
                        Text("指派角色")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))

                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("編輯成員角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: { dismiss() })
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(Array(selectedRoleIds), memberTitle.isEmpty ? nil : memberTitle)
                        dismiss()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: AppDesignSystem.accentColor))
                }
            }
        }
    }
    
    private func roleRow(for role: Role) -> some View {
        Button(action: {
            toggleSelection(for: role.id!)
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(role.name)
                        .font(AppDesignSystem.bodyFont)
                        .foregroundColor(.primary)
                    Text("\(role.permissions.count) 項權限")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedRoleIds.contains(role.id!) {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppDesignSystem.accentColor)
                }
            }
        }
    }
    
    private func toggleSelection(for roleId: String) {
        if selectedRoleIds.contains(roleId) {
            selectedRoleIds.remove(roleId)
        } else {
            selectedRoleIds.insert(roleId)
        }
    }
}