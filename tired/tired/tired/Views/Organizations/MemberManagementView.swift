import SwiftUI

@available(iOS 17.0, *)
struct MemberManagementView: View {
    @StateObject private var viewModel: MemberManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ManagementTab = .members
    @State private var showingCreateInvitation = false

    enum ManagementTab: String, CaseIterable {
        case members = "成員"
        case invitations = "邀請"
    }

    init(organization: Organization) {
        _viewModel = StateObject(wrappedValue: MemberManagementViewModel(organization: organization))
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
            NavigationView {
                VStack(spacing: 0) {
                    // Tab Selector
                    Picker("視圖", selection: $selectedTab) {
                        ForEach(ManagementTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.clear)

                    contentView
                }
                .navigationTitle("成員管理")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("關閉") { dismiss() }
                            .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if selectedTab == .invitations {
                            Button {
                                showingCreateInvitation = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .background(Color.clear)
            }
        }
        .sheet(isPresented: $showingCreateInvitation) {
            CreateInvitationView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .members:
            membersView
        case .invitations:
            invitationsView
        }
    }
    
    // MARK: - Members View
    
    private var membersView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("載入成員中...")
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else if viewModel.members.isEmpty {
                emptyState(title: "目前沒有成員", icon: "person.3.fill")
            } else {
                membersList
            }
        }
    }
    
    private var membersList: some View {
        List {
            ForEach(viewModel.members) { member in
                NavigationLink(destination: editMemberRolesView(for: member)) {
                    MemberRow(
                        member: member,
                        organization: viewModel.organization,
                        onRemove: {
                            removeMember(member)
                        },
                        canRemove: viewModel.canRemoveMember(member)
                    )
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Invitations View
    
    private var invitationsView: some View {
        Group {
            if viewModel.invitations.isEmpty {
                emptyState(title: "沒有有效的邀請", icon: "envelope.open.fill")
            } else {
                List {
                    ForEach(viewModel.invitations) { invitation in
                        InvitationRow(invitation: invitation) {
                            deleteInvitation(invitation)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func removeMember(_ member: MemberWithProfile) {
        _Concurrency.Task {
            await viewModel.removeMember(membership: member.membership)
        }
    }
    
    private func deleteInvitation(_ invitation: Invitation) {
        _Concurrency.Task {
            await viewModel.deleteInvitation(invitation)
        }
    }
    
    private func editMemberRolesView(for member: MemberWithProfile) -> some View {
        EditMemberRolesView(
            member: member,
            organization: viewModel.organization,
            onSave: { newRoleIds, title in
                _Concurrency.Task {
                    await viewModel.updateMemberRoles(membership: member.membership, newRoleIds: newRoleIds, title: title)
                }
            }
        )
    }
    
    private func emptyState(title: String, icon: String) -> some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: icon)
            .font(.system(size: 60))
            .foregroundColor(.secondary)
            Text(title)
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
    let onRemove: () -> Void
    let canRemove: Bool
    @State private var showingRemoveConfirmation = false

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
            
            if canRemove {
                Button {
                    showingRemoveConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
        .confirmationDialog("移除成員", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("移除", role: .destructive) {
                onRemove()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("確定要將 \(member.displayName) 從組織中移除嗎？")
        }
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

// MARK: - Invitation Row
@available(iOS 17.0, *)
struct InvitationRow: View {
    let invitation: Invitation
    let onDelete: () -> Void
    @State private var isCopied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("邀請碼：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(invitation.code)
                        .font(.title3.monospaced())
                        .fontWeight(.bold)
                }
                
                HStack {
                    if let max = invitation.maxUses {
                        Label("\(invitation.currentUses)/\(max) 次使用", systemImage: "person.2")
                    } else {
                        Label("無限次使用", systemImage: "infinity")
                    }
                    
                    if let exp = invitation.expirationDate {
                        Text("•")
                        if exp < Date() {
                            Text("已過期").foregroundColor(.red)
                        } else {
                            Text(exp, style: .date)
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                UIPasteboard.general.string = invitation.code
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isCopied = false
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(isCopied ? .green : .blue)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .glassmorphicCard()
    }
}

// MARK: - Create Invitation View
@available(iOS 17.0, *)
struct CreateInvitationView: View {
    @ObservedObject var viewModel: MemberManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var maxUsesType: UsesType = .unlimited
    @State private var customMaxUses = 10
    @State private var expirationType: ExpirationType = .forever
    @State private var customHours = 24
    
    enum UsesType: String, CaseIterable {
        case unlimited = "無限次"
        case single = "單次 (1次)"
        case custom = "自訂"
    }
    
    enum ExpirationType: String, CaseIterable {
        case forever = "永不過期"
        case oneDay = "24小時"
        case threeDays = "3天"
        case custom = "自訂 (小時)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("使用限制")) {
                    Picker("次數限制", selection: $maxUsesType) {
                        ForEach(UsesType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if maxUsesType == .custom {
                        Stepper("次數: \(customMaxUses)", value: $customMaxUses, in: 1...1000)
                    }
                }
                
                Section(header: Text("有效期限")) {
                    Picker("過期時間", selection: $expirationType) {
                        ForEach(ExpirationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if expirationType == .custom {
                        Stepper("小時: \(customHours)", value: $customHours, in: 1...720)
                    }
                }
                
                Section {
                    Button {
                        create()
                    } label: {
                        Text("產生邀請碼")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("建立邀請")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func create() {
        var maxUses: Int?
        switch maxUsesType {
        case .unlimited: maxUses = nil
        case .single: maxUses = 1
        case .custom: maxUses = customMaxUses
        }
        
        var hours: Int?
        switch expirationType {
        case .forever: hours = nil
        case .oneDay: hours = 24
        case .threeDays: hours = 72
        case .custom: hours = customHours
        }
        
        _Concurrency.Task {
            await viewModel.createInvitation(maxUses: maxUses, expirationHours: hours)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
