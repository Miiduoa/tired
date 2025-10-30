import SwiftUI
import Combine

@MainActor
final class MemberManagementViewModel: ObservableObject {
    @Published var members: [TenantMember] = []
    @Published var isLoading = false
    @Published var query: String = ""
    private let service: TenantAdminServiceProtocol
    private let groupId: String

    init(groupId: String, service: TenantAdminServiceProtocol = TenantAdminService()) {
        self.groupId = groupId
        self.service = service
    }

    func load() async {
        isLoading = true
        members = await service.listMembers(groupId: groupId)
        isLoading = false
    }

    func updateRole(for uid: String, to role: TenantMembership.Role) async {
        try? await service.updateRole(groupId: groupId, uid: uid, role: role)
        await load()
    }
}

struct MemberManagementView: View {
    let membership: TenantMembership
    @StateObject private var viewModel: MemberManagementViewModel
    @State private var showInvite = false
    @State private var inviteEmail = ""
    @State private var inviteRole: TenantMembership.Role = .member

    init(membership: TenantMembership) {
        self.membership = membership
        _viewModel = StateObject(wrappedValue: MemberManagementViewModel(groupId: membership.id))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("搜尋姓名或 Email", text: $viewModel.query)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                    if RolePermissions.canManageMembers(membership.role) {
                        Button("邀請") { showInvite = true }
                    }
                }
            }

            Section("成員") {
                ForEach(filteredMembers) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.displayName).font(.subheadline.weight(.medium))
                            if !m.email.isEmpty { Text(m.email).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if RolePermissions.canManageMembers(membership.role) {
                            Menu(m.role.displayName) {
                                ForEach(TenantMembership.Role.allCases, id: \.self) { r in
                                    Button(r.displayName) { Task { await viewModel.updateRole(for: m.id, to: r) } }
                                }
                            }
                            .font(.caption)
                        } else {
                            Text(m.role.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("成員管理")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showInvite) { inviteSheet }
    }

    private var filteredMembers: [TenantMember] {
        let q = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.members }
        return viewModel.members.filter { $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    private var inviteSheet: some View {
        NavigationStack {
            Form {
                Section("邀請資訊") {
                    TextField("Email", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                    Picker("角色", selection: $inviteRole) {
                        ForEach(TenantMembership.Role.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }
            }
            .navigationTitle("邀請成員")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showInvite = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送出") {
                        Task {
                            try? await TenantAdminService().inviteMember(groupId: membership.id, email: inviteEmail, role: inviteRole)
                            showInvite = false
                        }
                    }
                    .disabled(inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

