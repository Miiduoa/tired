import SwiftUI

@available(iOS 17.0, *)
struct OrganizationsView: View {
    @StateObject private var viewModel = OrganizationsViewModel()
    @State private var showingCreateOrganization = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 我加入的組織
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("我的身份")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Button {
                                showingCreateOrganization = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("創建組織")
                                }
                                .font(.system(size: 13))
                            }
                        }

                        if viewModel.myMemberships.isEmpty {
                            InfoCard(
                                title: "開始你的第一個身份",
                                description: "加入組織或創建新組織，開始使用多身份任務管理系統。"
                            )
                        } else {
                            ForEach(viewModel.myMemberships) { membershipWithOrg in
                                if let org = membershipWithOrg.organization {
                                    NavigationLink(destination: OrganizationDetailView(organization: org)) {
                                        OrganizationCard(
                                            organization: org,
                                            membership: membershipWithOrg.membership
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("我的身份")
            .sheet(isPresented: $showingCreateOrganization) {
                CreateOrganizationView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Organization Card

@available(iOS 17.0, *)
struct OrganizationCard: View {
    let organization: Organization
    let membership: Membership

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = organization.avatarUrl {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    organizationInitials
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                organizationInitials
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(organization.name)
                        .font(.system(size: 15, weight: .medium))

                    if organization.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }

                HStack(spacing: 8) {
                    Text(organization.type.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(membership.role.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if let title = membership.title {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }

    private var organizationInitials: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(colorForOrgType(organization.type))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(organization.name.prefix(2)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func colorForOrgType(_ type: OrgType) -> Color {
        switch type {
        case .school: return .blue
        case .department: return .cyan
        case .club: return .purple
        case .company: return .orange
        case .project: return .green
        case .other: return .gray
        }
    }
}

// MARK: - Create Organization View

@available(iOS 17.0, *)
struct CreateOrganizationView: View {
    @ObservedObject var viewModel: OrganizationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: OrgType = .school
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("組織名稱", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("類型", selection: $type) {
                        ForEach(OrgType.allCases, id: \.self) { orgType in
                            HStack {
                                Image(systemName: iconForOrgType(orgType))
                                Text(orgType.displayName)
                            }
                            .tag(orgType)
                        }
                    }
                }

                Section("描述（選填）") {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
            }
            .navigationTitle("創建組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("創建") {
                        createOrganization()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createOrganization() {
        isCreating = true

        Task {
            do {
                let desc = description.isEmpty ? nil : description
                _ = try await viewModel.createOrganization(
                    name: name,
                    type: type,
                    description: desc
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating organization: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }

    private func iconForOrgType(_ type: OrgType) -> String {
        switch type {
        case .school: return "building.columns"
        case .department: return "building.2"
        case .club: return "music.note.house"
        case .company: return "briefcase"
        case .project: return "folder"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Info Card (重用)

@available(iOS 17.0, *)
struct InfoCard: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}
