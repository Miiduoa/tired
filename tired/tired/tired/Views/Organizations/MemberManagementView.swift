import SwiftUI

@available(iOS 17.0, *)
struct MemberManagementView: View {
    @StateObject private var viewModel: MemberManagementViewModel
    @Environment(\.dismiss) private var dismiss

    init(organization: Organization) {
        _viewModel = StateObject(wrappedValue: MemberManagementViewModel(organization: organization))
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                Group {
                    if viewModel.isLoading {
                        ProgressView("載入成員中...")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    } else if viewModel.members.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(viewModel.members) { member in
                                NavigationLink(destination: EditMemberRolesView(
                                    member: member,
                                    organization: viewModel.organization,
                                    onSave: { newRoleIds in
                                        Task {
                                            await viewModel.updateMemberRoles(membership: member.membership, newRoleIds: newRoleIds)
                                        }
                                    }
                                )) {
                                    MemberRow(member: member, organization: viewModel.organization)
                                }
                                .listRowBackground(Color.clear) // Make list row transparent
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("成員管理")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("關閉") { dismiss() }
                            .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, textColor: .red, cornerRadius: AppDesignSystem.cornerRadiusSmall))
                    }
                }
                .alert(item: $viewModel.alertConfig) { config in
                    Alert(title: Text(config.title), message: Text(config.message), dismissButton: .default(Text("確定")))
                }
                .background(Color.clear) // Make NavigationView's background clear
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("目前沒有成員")
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.primary)
        }
        .padding(AppDesignSystem.paddingLarge)
        .glassmorphicCard()
        .padding(.horizontal, AppDesignSystem.paddingLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Member Row
@available(iOS 17.0, *)
struct MemberRow: View {
    let member: MemberWithProfile
    let organization: Organization

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // Avatar
            if let avatarUrl = member.avatarUrl {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: { avatarPlaceholder }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            // User Info
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                Text(member.displayName).font(AppDesignSystem.bodyFont.weight(.medium))
                    .foregroundColor(.primary)
                
                // Display roles
                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    let roleNames = member.membership.roleIds.compactMap { roleId in
                        organization.roles.first { $0.id == roleId }?.name
                    }
                    if roleNames.isEmpty {
                        Text("成員").font(AppDesignSystem.captionFont).foregroundColor(.secondary)
                    } else {
                        ForEach(roleNames, id: \.self) { name in
                            Text(name)
                                .font(AppDesignSystem.captionFont)
                                .padding(.horizontal, AppDesignSystem.paddingSmall)
                                .padding(.vertical, AppDesignSystem.paddingSmall / 2)
                                .background(AppDesignSystem.accentColor.opacity(0.1))
                                .foregroundColor(AppDesignSystem.accentColor)
                                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                    .foregroundColor(.secondary)
            )
    }
}