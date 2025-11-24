import SwiftUI

@available(iOS 17.0, *)
struct OrganizationsView: View {
    @StateObject private var viewModel = OrganizationsViewModel()
    @State private var showingCreateOrganization = false
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 我加入的組織
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
                            HStack {
                                Text("我的身份")
                                    .font(AppDesignSystem.headlineFont)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button {
                                    showingSearch = true
                                } label: {
                                    Label("搜索", systemImage: "magnifyingglass")
                                        .font(AppDesignSystem.captionFont.weight(.semibold))
                                }
                                .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: AppDesignSystem.accentColor))

                                Button {
                                    showingCreateOrganization = true
                                } label: {
                                    Label("創建", systemImage: "plus.circle.fill")
                                        .font(AppDesignSystem.captionFont.weight(.semibold))
                                }
                                .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: AppDesignSystem.accentColor))
                            }

                            if viewModel.myMemberships.isEmpty {
                                InfoCard(
                                    title: "開始你的第一個身份",
                                    description: "加入組織或創建新組織，開始使用多身份任務管理系統。"
                                )
                                .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium) // Apply glassmorphic to info card
                            } else {
                                ForEach(viewModel.myMemberships, id: \.id) { membershipWithOrg in
                                    if let org = membershipWithOrg.organization {
                                        NavigationLink(destination: OrganizationDetailView(organizationId: org.id ?? "")) {
                                            OrganizationCard(
                                                organization: org,
                                                membership: membershipWithOrg.membership
                                            )
                                        }
                                        .buttonStyle(.plain) // Remove default button styling for NavigationLink
                                    }
                                }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                    }
                }
                .navigationTitle("我的身份")
                .navigationBarTitleDisplayMode(.large)
                .background(Color.clear) // Make NavigationView's background clear
                .sheet(isPresented: $showingCreateOrganization) {
                    CreateOrganizationView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingSearch) {
                    SearchOrganizationsView(viewModel: viewModel)
                }
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
        HStack(spacing: AppDesignSystem.paddingMedium) {
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
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall))
            } else {
                organizationInitials
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    Text(organization.name)
                        .font(AppDesignSystem.bodyFont.weight(.medium))
                        .foregroundColor(.primary)

                    if organization.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppDesignSystem.accentColor)
                            .font(AppDesignSystem.captionFont)
                    }
                }

                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    Text(organization.type.displayName)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)
                    
                    let roleNames = membership.roleIds.compactMap { roleId in
                        organization.roles.first { $0.id == roleId }?.name
                    }
                    
                    Text(roleNames.joined(separator: ", "))
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let title = membership.title {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(AppDesignSystem.bodyFont)
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium) // Apply glassmorphic effect
    }

    private var organizationInitials: some View {
        RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
            .fill(colorForOrgType(organization.type).opacity(0.8))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(organization.name.prefix(2)).uppercased())
                    .font(AppDesignSystem.headlineFont)
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
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet
                Form {
                    Section {
                        TextField("組織名稱", text: $name)
                            .textFieldStyle(FrostedTextFieldStyle())

                        Picker("類型", selection: $type) {
                            ForEach(OrgType.allCases, id: \.self) { orgType in
                                HStack {
                                    Image(systemName: iconForOrgType(orgType))
                                    Text(orgType.displayName)
                                }
                                .tag(orgType)
                            }
                        }
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                        .listRowBackground(Color.clear) // Make form row transparent
                    } header: {
                        Text("基本信息")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)

                    Section {
                        TextEditor(text: $description)
                            .font(AppDesignSystem.bodyFont)
                            .padding(AppDesignSystem.paddingSmall)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                            .frame(height: 100)
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("描述（選填）")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)
                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("創建組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("創建") {
                        createOrganization()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createOrganization() {
        isCreating = true

        _Concurrency.Task {
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
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            Text(title)
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.primary)
            Text(description)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Search Organizations View

@available(iOS 17.0, *)
struct SearchOrganizationsView: View {
    @ObservedObject var viewModel: OrganizationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.title2)
                        TextField("搜索組織名稱", text: $searchQuery)
                            .textFieldStyle(.plain) // Use plain style inside custom background
                            .font(AppDesignSystem.bodyFont)
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                viewModel.allOrganizations = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(AppDesignSystem.paddingMedium)
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial) // Apply glassmorphic
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingSmall)


                    // Search results
                    if viewModel.isLoading {
                        ProgressView("搜索中...")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.primary)
                            .padding(AppDesignSystem.paddingLarge)
                    } else if searchQuery.isEmpty {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("搜索組織")
                                .font(AppDesignSystem.headlineFont)
                                .foregroundColor(.primary)
                            Text("輸入組織名稱開始搜索")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                        }
                        .padding(AppDesignSystem.paddingLarge)
                        .glassmorphicCard()
                        .padding(.vertical, AppDesignSystem.paddingLarge)
                    } else if viewModel.allOrganizations.isEmpty {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("未找到組織")
                                .font(AppDesignSystem.headlineFont)
                                .foregroundColor(.primary)
                            Text("試試其他關鍵詞")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                        }
                        .padding(AppDesignSystem.paddingLarge)
                        .glassmorphicCard()
                        .padding(.vertical, AppDesignSystem.paddingLarge)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppDesignSystem.paddingMedium) {
                                ForEach(viewModel.allOrganizations, id: \.id) { org in
                                    SearchResultCard(
                                        organization: org,
                                        onRequest: {
                                            requestToJoin(org)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("搜索組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
            }
            .background(Color.clear) // Make NavigationView's background clear
        }
    }

    private func performSearch() {
        _Concurrency.Task {
            await viewModel.searchOrganizations(query: searchQuery)
        }
    }

    private func requestToJoin(_ org: Organization) {
        guard let orgId = org.id else { return }

        _Concurrency.Task {
            do {
                try await viewModel.requestToJoinOrganization(organizationId: orgId)
                await MainActor.run {
                    ToastManager.shared.showToast(message: "申請已送出！等待審核。", type: .success)
                    dismiss()
                }
            } catch {
                print("❌ Error requesting to join organization: \(error)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "申請失敗: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}

// MARK: - Search Result Card

@available(iOS 17.0, *)
struct SearchResultCard: View {
    let organization: Organization
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
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
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall))
            } else {
                organizationInitials
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    Text(organization.name)
                        .font(AppDesignSystem.bodyFont.weight(.medium))
                        .foregroundColor(.primary)

                    if organization.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppDesignSystem.accentColor)
                            .font(AppDesignSystem.captionFont)
                    }
                }

                Text(organization.type.displayName)
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)

                if let description = organization.description {
                    Text(description)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                onRequest()
            } label: {
                Text("申請加入")
                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingSmall)
                    .background(AppDesignSystem.accentColor)
                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
            }
            .buttonStyle(.plain) // Remove default button styling for custom background
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium) // Apply glassmorphic effect
    }

    private var organizationInitials: some View {
        RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
            .fill(colorForOrgType(organization.type).opacity(0.8))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(organization.name.prefix(2)).uppercased())
                    .font(AppDesignSystem.headlineFont)
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