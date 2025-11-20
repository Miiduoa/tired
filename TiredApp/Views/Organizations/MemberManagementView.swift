import SwiftUI
import FirebaseAuth

@available(iOS 17.0, *)
struct MemberManagementView: View {
    let organization: Organization
    @StateObject private var viewModel: MemberManagementViewModel
    @Environment(\.dismiss) private var dismiss

    init(organization: Organization, currentMembership: Membership) {
        self.organization = organization
        self._viewModel = StateObject(wrappedValue: MemberManagementViewModel(
            organization: organization,
            currentMembership: currentMembership
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("載入成員中...")
                        Spacer()
                    }
                } else {
                    List {
                        // 成員列表
                        ForEach(viewModel.members) { memberWithProfile in
                            MemberRow(
                                member: memberWithProfile,
                                currentMembership: viewModel.currentMembership,
                                onChangeRole: { newRole in
                                    viewModel.changeRole(member: memberWithProfile.membership, to: newRole)
                                },
                                onRemove: {
                                    viewModel.removeMember(memberWithProfile.membership)
                                },
                                onTransferOwnership: {
                                    viewModel.transferOwnership(to: memberWithProfile.membership)
                                }
                            )
                        }
                    }
                    .listStyle(.plain)

                    // 成員統計
                    VStack(spacing: 8) {
                        HStack {
                            Text("總成員數")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.members.count)")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        // 按角色統計
                        ForEach(MembershipRole.allCases, id: \.self) { role in
                            let count = viewModel.members.filter { $0.membership.role == role }.count
                            if count > 0 {
                                HStack {
                                    Text(role.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.system(size: 13))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.appSecondaryBackground)
                }
            }
            .navigationTitle("成員管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .alert(item: $viewModel.alertConfig) { config in
                Alert(
                    title: Text(config.title),
                    message: Text(config.message),
                    dismissButton: .default(Text("確定"))
                )
            }
        }
    }
}

// MARK: - Member Row

@available(iOS 17.0, *)
struct MemberRow: View {
    let member: MemberWithProfile
    let currentMembership: Membership
    let onChangeRole: (MembershipRole) -> Void
    let onRemove: () -> Void
    let onTransferOwnership: () -> Void

    @State private var showingRoleSheet = false
    @State private var showingRemoveAlert = false
    @State private var showingTransferAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 頭像
                if let avatarUrl = member.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                // 用戶資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(.system(size: 16, weight: .medium))

                    HStack(spacing: 4) {
                        // 角色標籤
                        Text(member.membership.role.displayName)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(roleColor(member.membership.role).opacity(0.2))
                            .foregroundColor(roleColor(member.membership.role))
                            .cornerRadius(4)

                        if let title = member.membership.title {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(title)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // 操作按鈕（僅對可管理的成員顯示）
                if canManageMember {
                    Menu {
                        if canChangeRole {
                            Button {
                                showingRoleSheet = true
                            } label: {
                                Label("變更角色", systemImage: "person.badge.key")
                            }
                        }

                        if currentMembership.role == .owner && member.membership.role != .owner {
                            Button {
                                showingTransferAlert = true
                            } label: {
                                Label("轉移所有權", systemImage: "arrow.triangle.swap")
                            }
                        }

                        if canRemove {
                            Divider()
                            Button(role: .destructive) {
                                showingRemoveAlert = true
                            } label: {
                                Label("移除成員", systemImage: "person.badge.minus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                }
            }

            // 角色說明（當前用戶自己）
            if member.membership.userId == currentMembership.userId {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("這是你")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingRoleSheet) {
            RoleSelectionSheet(
                currentRole: member.membership.role,
                availableRoles: availableRoles,
                onSelect: { newRole in
                    onChangeRole(newRole)
                    showingRoleSheet = false
                }
            )
        }
        .alert("移除成員", isPresented: $showingRemoveAlert) {
            Button("取消", role: .cancel) {}
            Button("移除", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("確定要移除 \(member.displayName) 嗎？此操作無法撤銷。")
        }
        .alert("轉移所有權", isPresented: $showingTransferAlert) {
            Button("取消", role: .cancel) {}
            Button("轉移", role: .destructive) {
                onTransferOwnership()
            }
        } message: {
            Text("確定要將組織所有權轉移給 \(member.displayName) 嗎？你將成為管理員。")
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 48, height: 48)
            .overlay(
                Text(String(member.displayName.prefix(2)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            )
    }

    private func roleColor(_ role: MembershipRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .orange
        case .staff: return .blue
        case .student: return .green
        case .member: return .gray
        }
    }

    private var canManageMember: Bool {
        currentMembership.canManageMember(member.membership)
    }

    private var canChangeRole: Bool {
        currentMembership.hasPermission(.changeRoles) && canManageMember
    }

    private var canRemove: Bool {
        currentMembership.hasPermission(.removeMembers) && canManageMember
    }

    private var availableRoles: [MembershipRole] {
        MembershipRole.allCases.filter { role in
            currentMembership.canChangeRoleTo(role)
        }
    }
}

// MARK: - Role Selection Sheet

@available(iOS 17.0, *)
struct RoleSelectionSheet: View {
    let currentRole: MembershipRole
    let availableRoles: [MembershipRole]
    let onSelect: (MembershipRole) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(availableRoles, id: \.self) { role in
                    Button {
                        onSelect(role)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)

                                Text(role.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if role == currentRole {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("選擇角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Member Management ViewModel

class MemberManagementViewModel: ObservableObject {
    @Published var members: [MemberWithProfile] = []
    @Published var isLoading = false
    @Published var alertConfig: AlertConfig?

    let organization: Organization
    let currentMembership: Membership

    private let organizationService = OrganizationService()
    private let userService = UserService()

    init(organization: Organization, currentMembership: Membership) {
        self.organization = organization
        self.currentMembership = currentMembership
        loadMembers()
    }

    func loadMembers() {
        guard let orgId = organization.id else { return }

        isLoading = true

        Task {
            do {
                // 獲取所有成員
                let memberships = try await organizationService.fetchOrganizationMembers(organizationId: orgId)

                // 獲取用戶資料
                let userIds = memberships.map { $0.userId }
                let profiles = try await userService.fetchUserProfiles(userIds: userIds)

                // 組合資料
                let membersWithProfiles = memberships.map { membership in
                    MemberWithProfile(
                        membership: membership,
                        userProfile: profiles[membership.userId]
                    )
                }

                // 按角色層級排序（owner在最上面）
                let sorted = membersWithProfiles.sorted {
                    $0.membership.role.hierarchyLevel > $1.membership.role.hierarchyLevel
                }

                await MainActor.run {
                    self.members = sorted
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading members: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.alertConfig = AlertConfig(
                        title: "錯誤",
                        message: "載入成員失敗：\(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }

    func changeRole(member: Membership, to newRole: MembershipRole) {
        guard let memberId = member.id else { return }

        Task {
            do {
                try await organizationService.changeMemberRole(membershipId: memberId, newRole: newRole)

                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "成功",
                        message: "已變更角色為 \(newRole.displayName)",
                        type: .success
                    )
                }

                loadMembers()
            } catch {
                print("❌ Error changing role: \(error)")
                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "錯誤",
                        message: "變更角色失敗：\(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }

    func removeMember(_ member: Membership) {
        guard let memberId = member.id else { return }

        Task {
            do {
                try await organizationService.deleteMembership(id: memberId)

                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "成功",
                        message: "已移除成員",
                        type: .success
                    )
                }

                loadMembers()
            } catch {
                print("❌ Error removing member: \(error)")
                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "錯誤",
                        message: "移除成員失敗：\(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }

    func transferOwnership(to member: Membership) {
        guard let orgId = organization.id else { return }

        Task {
            do {
                try await organizationService.transferOwnership(
                    organizationId: orgId,
                    fromUserId: currentMembership.userId,
                    toUserId: member.userId
                )

                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "成功",
                        message: "已轉移所有權",
                        type: .success
                    )
                }

                loadMembers()
            } catch {
                print("❌ Error transferring ownership: \(error)")
                await MainActor.run {
                    self.alertConfig = AlertConfig(
                        title: "錯誤",
                        message: "轉移所有權失敗：\(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }
}
