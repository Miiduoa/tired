import SwiftUI
import Combine

// 保留原有 ViewModel

// MARK: - 🎨 現代化成員管理

struct MemberManagementView_Modern: View {
    let membership: TenantMembership
    @StateObject private var viewModel: MemberManagementViewModel
    @State private var showInvite = false
    @State private var inviteEmail = ""
    @State private var inviteRole: TenantMembership.Role = .member
    @State private var selectedMember: TenantMember? = nil

    init(membership: TenantMembership) {
        self.membership = membership
        _viewModel = StateObject(wrappedValue: MemberManagementViewModel(groupId: membership.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if viewModel.isLoading && viewModel.members.isEmpty {
                        loadingView
                    } else if filteredMembers.isEmpty {
                        emptyView
                    } else {
                        membersList
                    }
                }
            }
            .navigationTitle("成員管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if RolePermissions.canManageMembers(membership.role) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticFeedback.light()
                            showInvite = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showInvite) {
                InviteMemberSheet(
                    membership: membership,
                    email: $inviteEmail,
                    role: $inviteRole
                ) {
                    await viewModel.load()
                }
            }
            .sheet(item: $selectedMember) { member in
                MemberDetailSheet(
                    member: member,
                    canManage: RolePermissions.canManageMembers(membership.role)
                ) { newRole in
                    await viewModel.updateRole(for: member.id, to: newRole)
                    selectedMember = nil
                }
            }
        }
    }
    
    // MARK: - 搜索欄
    
    private var searchBar: some View {
        HStack(spacing: TTokens.spacingMD) {
            HStack(spacing: TTokens.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                
                TextField("搜尋姓名或 Email", text: $viewModel.query)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
                
                if !viewModel.query.isEmpty {
                    Button {
                        HapticFeedback.light()
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(TTokens.spacingMD)
            .background(Color.neutralLight.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
    }
    
    // MARK: - 加載視圖
    
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonCard()
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.06),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - 空狀態
    
    private var emptyView: some View {
        AppEmptyStateView(
            systemImage: "person.3.fill",
            title: viewModel.query.isEmpty ? "目前沒有成員" : "找不到符合的成員",
            subtitle: viewModel.query.isEmpty ? "邀請成員加入組織" : "試試調整搜尋條件"
        )
    }
    
    // MARK: - 成員列表
    
    private var membersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 統計摘要
                statsCard
                
                // 成員列表
                ForEach(Array(filteredMembers.enumerated()), id: \.element.id) { index, member in
                    Button {
                        HapticFeedback.light()
                        selectedMember = member
                    } label: {
                        MemberCard(member: member, canManage: RolePermissions.canManageMembers(membership.role))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index % 10) * 0.04),
                        value: filteredMembers.count
                    )
                }
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - 統計卡片
    
    private var statsCard: some View {
        HStack(spacing: TTokens.spacingLG) {
            StatPill(label: "總人數", value: "\(viewModel.members.count)", icon: "person.3.fill", color: .tint)
            StatPill(label: "管理員", value: "\(adminCount)", icon: "crown.fill", color: .creative)
            StatPill(label: "成員", value: "\(memberCount)", icon: "person.fill", color: .mint)
        }
        .padding(16)
    }
    
    private var filteredMembers: [TenantMember] {
        let q = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.members }
        return viewModel.members.filter { $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }
    
    private var adminCount: Int {
        viewModel.members.filter { $0.role == .admin || $0.role == .owner }.count
    }
    
    private var memberCount: Int {
        viewModel.members.filter { $0.role == .member }.count
    }
}

// MARK: - 統計藥丸

private struct StatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TTokens.spacingLG)
        .glassEffect(intensity: 0.6)
    }
}

// MARK: - 成員卡片

private struct MemberCard: View {
    let member: TenantMember
    let canManage: Bool
    
    var body: some View {
        HStack(spacing: TTokens.spacingMD) {
            // 頭像
            AvatarRing(
                imageURL: nil,
                size: 56,
                ringColor: roleColor,
                ringWidth: 2
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.semibold))
                    
                    if member.role == .owner || member.role == .admin {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.creative)
                    }
                }
                
                if !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 角色徽章
            TagBadge(
                member.role.displayName,
                color: roleColor,
                icon: roleIcon
            )
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
    
    private var roleColor: Color {
        switch member.role {
        case .owner: return Color.creative
        case .admin: return Color.mint
        case .member: return Color.tint
        @unknown default: return Color.tint
        }
    }
    
    private var roleIcon: String {
        switch member.role {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .member: return "person.fill"
        @unknown default: return "person.fill"
        }
    }
}

// MARK: - 邀請彈窗

private struct InviteMemberSheet: View {
    let membership: TenantMembership
    @Binding var email: String
    @Binding var role: TenantMembership.Role
    let onComplete: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: TTokens.spacingXL) {
                    Spacer()
                    
                    // 圖標
                    ZStack {
                        Circle()
                            .fill(TTokens.gradientPrimary.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(TTokens.gradientPrimary)
                    }
                    .shadow(color: .tint.opacity(0.3), radius: 20, y: 10)
                    
                    // 表單
                    VStack(spacing: TTokens.spacingLG) {
                        ModernFormField(
                            title: "Email",
                            placeholder: "輸入成員 Email",
                            text: $email,
                            icon: "envelope.fill"
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("角色")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            Picker("角色", selection: $role) {
                                ForEach(TenantMembership.Role.allCases, id: \.self) { r in
                                    Text(r.displayName).tag(r)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Button {
                            HapticFeedback.medium()
                            Task {
                                isSubmitting = true
                                // TODO: 實際邀請 API
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                await onComplete()
                                isSubmitting = false
                                HapticFeedback.success()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("發送邀請")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: TTokens.touchTargetComfortable)
                        }
                        .fluidButton(gradient: canSubmit ? TTokens.gradientPrimary : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding(TTokens.spacingLG)
                    
                    Spacer()
                }
            }
            .navigationTitle("邀請成員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@")
    }
}

// MARK: - 成員詳情彈窗

private struct MemberDetailSheet: View {
    let member: TenantMember
    let canManage: Bool
    let onUpdateRole: (TenantMembership.Role) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: TenantMembership.Role
    @State private var isUpdating = false
    
    init(member: TenantMember, canManage: Bool, onUpdateRole: @escaping (TenantMembership.Role) async -> Void) {
        self.member = member
        self.canManage = canManage
        self.onUpdateRole = onUpdateRole
        _selectedRole = State(initialValue: member.role)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TTokens.spacingXL) {
                        // 頭像
                        AvatarRing(
                            imageURL: nil,
                            size: 100,
                            ringColor: roleColor,
                            ringWidth: 3
                        )
                        
                        // 成員信息
                        VStack(spacing: 8) {
                            Text(member.displayName)
                                .font(.title2.weight(.bold))
                            
                            Text(member.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 角色管理
                        if canManage {
                            VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                                Text("角色權限")
                                    .font(.headline)
                                
                                Picker("角色", selection: $selectedRole) {
                                    ForEach(TenantMembership.Role.allCases, id: \.self) { r in
                                        Text(r.displayName).tag(r)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if selectedRole != member.role {
                                    Button {
                                        HapticFeedback.medium()
                                        Task {
                                            isUpdating = true
                                            await onUpdateRole(selectedRole)
                                            isUpdating = false
                                            HapticFeedback.success()
                                        }
                                    } label: {
                                        HStack {
                                            if isUpdating {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.white)
                                            } else {
                                                Text("更新角色")
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: TTokens.touchTargetComfortable)
                                    }
                                    .fluidButton(gradient: TTokens.gradientPrimary)
                                    .disabled(isUpdating)
                                }
                            }
                            .padding(TTokens.spacingLG)
                            .floatingCard()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("成員詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var roleColor: Color {
        switch member.role {
        case .owner: return Color.creative
        case .admin: return Color.mint
        case .member: return Color.tint
        @unknown default: return Color.tint
        }
    }
}

