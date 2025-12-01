import SwiftUI

@available(iOS 17.0, *)
struct OrganizationsView: View {
    @StateObject private var viewModel = OrganizationsViewModel()
    @State private var showingCreateOrganization = false
    @State private var showingSearch = false
    @State private var showingJoinByCode = false
    @State private var invitationCode = ""

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
                                    showingJoinByCode = true
                                } label: {
                                    Label("加入", systemImage: "keyboard")
                                        .font(AppDesignSystem.captionFont.weight(.semibold))
                                }
                                .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: AppDesignSystem.accentColor))
                                
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
                    CreateOrganizationView(
                        viewModel: viewModel,
                        isPresented: $showingCreateOrganization
                    )
                }
                .sheet(isPresented: $showingSearch) {
                    SearchOrganizationsView(viewModel: viewModel)
                }
                .alert("輸入邀請碼", isPresented: $showingJoinByCode) {
                    TextField("邀請碼 (8碼)", text: $invitationCode)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                    Button("加入") {
                        joinByCode()
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text("請輸入組織提供的 8 碼邀請碼")
                }
            }
        }
    }
    
    private func joinByCode() {
        guard !invitationCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            ToastManager.shared.showToast(message: "請輸入邀請碼", type: .error)
            return
        }
        
        _Concurrency.Task {
            do {
                let orgId = try await viewModel.joinByInvitationCode(code: invitationCode.trimmingCharacters(in: .whitespaces))
                await MainActor.run {
                    invitationCode = "" // clear on success
                    // 成功消息由 ViewModel 處理
                }
            } catch {
                // error handled in VM
                await MainActor.run {
                    invitationCode = "" // 清空以便重新輸入
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
        case .course: return .green
        case .club: return .purple
        case .company: return .orange
        case .project: return .mint
        case .other: return .gray
        }
    }
}

// MARK: - Create Organization View

@available(iOS 17.0, *)
struct CreateOrganizationView: View {
    @ObservedObject var viewModel: OrganizationsViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: OrgType = .school
    @State private var description = ""
    @State private var isCreating = false

    // 層級相關
    @State private var selectedParentOrg: Organization?
    @State private var showingParentOrgPicker = false

    // 課程資訊
    @State private var courseCode = ""
    @State private var semester = ""
    @State private var academicYear = ""
    @State private var credits = "3"
    @State private var maxEnrollment = ""

    // 可選的組織類型（根據父組織類型動態變化）
    private var availableOrgTypes: [OrgType] {
        if let parent = selectedParentOrg {
            return parent.type.allowedChildTypes
        }
        // 沒有父組織時，只能創建根組織類型
        return [.school, .company, .club, .project, .other]
    }

    // 是否顯示課程資訊表單
    private var shouldShowCourseInfo: Bool {
        type == .course
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 層級結構區塊
                        VStack(alignment: .leading, spacing: 16) {
                            Text("組織層級")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Button {
                                showingParentOrgPicker = true
                            } label: {
                                HStack {
                                    if let parent = selectedParentOrg {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("父組織")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Label(parent.name, systemImage: iconForOrgType(parent.type))
                                                .foregroundColor(.primary)
                                        }
                                    } else {
                                        Label("選擇父組織（可選）", systemImage: "arrow.up.square")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedParentOrg != nil {
                                        Button {
                                            selectedParentOrg = nil
                                            // 重置為根組織類型
                                            if !availableOrgTypes.contains(type) {
                                                type = .school
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding()
                            .glassmorphicCard()
                        }

                        // 基本信息區塊
                        VStack(alignment: .leading, spacing: 16) {
                            Text("基本信息")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            VStack(spacing: 12) {
                                // 組織名稱輸入
                                TextField("組織名稱", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .foregroundColor(.primary)

                                // 類型選擇
                                Menu {
                                    Picker("類型", selection: $type) {
                                        ForEach(availableOrgTypes, id: \.self) { orgType in
                                            Label(orgType.displayName, systemImage: iconForOrgType(orgType))
                                                .tag(orgType)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Label(type.displayName, systemImage: iconForOrgType(type))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .padding()
                            .glassmorphicCard()
                        }
                        
                        // 描述區塊
                        VStack(alignment: .leading, spacing: 16) {
                            Text("描述（選填）")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            TextEditor(text: $description)
                                .frame(height: 120)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .foregroundColor(.primary)
                                .padding()
                                .glassmorphicCard()
                        }

                        // 課程資訊區塊（僅課程類型顯示）
                        if shouldShowCourseInfo {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("課程資訊")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                VStack(spacing: 12) {
                                    // 課程代碼
                                    TextField("課程代碼（例如：CS101）", text: $courseCode)
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                        .foregroundColor(.primary)

                                    HStack(spacing: 12) {
                                        // 學年
                                        TextField("學年（例如：2024）", text: $academicYear)
                                            .textFieldStyle(.plain)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .foregroundColor(.primary)
                                            .keyboardType(.numberPad)

                                        // 學期
                                        TextField("學期（例如：1）", text: $semester)
                                            .textFieldStyle(.plain)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .foregroundColor(.primary)
                                            .keyboardType(.numberPad)
                                    }

                                    HStack(spacing: 12) {
                                        // 學分數
                                        TextField("學分", text: $credits)
                                            .textFieldStyle(.plain)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .foregroundColor(.primary)
                                            .keyboardType(.numberPad)

                                        // 最大選課人數
                                        TextField("最大人數（選填）", text: $maxEnrollment)
                                            .textFieldStyle(.plain)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .foregroundColor(.primary)
                                            .keyboardType(.numberPad)
                                    }
                                }
                                .padding()
                                .glassmorphicCard()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("創建組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createOrganization()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Text("創建")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(name.isEmpty || isCreating || !isFormValid)
                }
            }
            .sheet(isPresented: $showingParentOrgPicker) {
                ParentOrganizationPickerView(
                    memberships: viewModel.myMemberships,
                    selectedOrganization: $selectedParentOrg,
                    onSelect: { org in
                        selectedParentOrg = org
                        // 自動調整類型為第一個允許的子組織類型
                        if let firstAllowed = org.type.allowedChildTypes.first {
                            type = firstAllowed
                        }
                        showingParentOrgPicker = false
                    }
                )
            }
        }
    }

    // 驗證表單是否有效
    private var isFormValid: Bool {
        if shouldShowCourseInfo {
            return !courseCode.isEmpty && !semester.isEmpty && !academicYear.isEmpty && !credits.isEmpty
        }
        return true
    }

    private func createOrganization() {
        guard !name.isEmpty else { return }

        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        withAnimation {
            isCreating = true
        }
        print("🚀 Starting createOrganization flow in View...")

        _Concurrency.Task {
            do {
                let desc = description.isEmpty ? nil : description

                // 準備課程資訊（如果是課程類型）
                var courseInfo: CourseInfo? = nil
                if shouldShowCourseInfo {
                    let creditsInt = Int(credits) ?? 3
                    let maxEnrollmentInt = maxEnrollment.isEmpty ? nil : Int(maxEnrollment)
                    courseInfo = CourseInfo(
                        courseCode: courseCode,
                        semester: "\(academicYear)-\(semester)",
                        academicYear: academicYear,
                        credits: creditsInt,
                        maxEnrollment: maxEnrollmentInt
                    )
                }

                print("Calling viewModel.createOrganization...")

                // 執行創建邏輯
                _ = try await viewModel.createOrganization(
                    name: name,
                    type: type,
                    description: desc,
                    parentOrganizationId: selectedParentOrg?.id,
                    courseInfo: courseInfo
                )
                print("✅ viewModel.createOrganization returned successfully.")

                // 強制在主線程執行 UI 更新和關閉操作
                DispatchQueue.main.async {
                    print("📲 Updating UI on Main Queue...")
                    self.isCreating = false
                    self.isPresented = false
                    self.dismiss()
                    print("👋 Dismiss actions called.")
                }
            } catch {
                print("❌ Error creating organization: \(error)")
                DispatchQueue.main.async {
                    self.isCreating = false
                    // 錯誤提示由 ViewModel 的 ToastManager 處理
                }
            }
        }
    }

    private func iconForOrgType(_ type: OrgType) -> String {
        switch type {
        case .school: return "building.columns"
        case .department: return "building.2"
        case .course: return "book.closed"
        case .club: return "music.note.house"
        case .company: return "briefcase"
        case .project: return "folder"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Parent Organization Picker View

@available(iOS 17.0, *)
struct ParentOrganizationPickerView: View {
    let memberships: [MembershipWithOrg]
    @Binding var selectedOrganization: Organization?
    let onSelect: (Organization) -> Void
    @Environment(\.dismiss) private var dismiss

    // 過濾出可以創建子組織的組織
    private var selectableOrganizations: [Organization] {
        memberships.compactMap { membership in
            guard let org = membership.organization else { return nil }
            // 只顯示能創建子組織的類型
            return org.type.canHaveChildren ? org : nil
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                if selectableOrganizations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("沒有可用的父組織")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("您需要先加入或創建一個學校、公司或系所類型的組織")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(selectableOrganizations, id: \.id) { org in
                                Button {
                                    onSelect(org)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Icon
                                        Image(systemName: iconForOrgType(org.type))
                                            .font(.title2)
                                            .foregroundColor(colorForOrgType(org.type))
                                            .frame(width: 40, height: 40)
                                            .background(colorForOrgType(org.type).opacity(0.2))
                                            .cornerRadius(8)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(org.name)
                                                .font(.body.weight(.medium))
                                                .foregroundColor(.primary)

                                            HStack(spacing: 4) {
                                                Text(org.type.displayName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                if org.type.canHaveChildren {
                                                    Text("·")
                                                        .foregroundColor(.secondary)
                                                    Text("可創建：\(org.type.allowedChildTypes.map { $0.displayName }.joined(separator: ", "))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .glassmorphicCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("選擇父組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func iconForOrgType(_ type: OrgType) -> String {
        switch type {
        case .school: return "building.columns"
        case .department: return "building.2"
        case .course: return "book.closed"
        case .club: return "music.note.house"
        case .company: return "briefcase"
        case .project: return "folder"
        case .other: return "square.grid.2x2"
        }
    }

    private func colorForOrgType(_ type: OrgType) -> Color {
        switch type {
        case .school: return .blue
        case .department: return .cyan
        case .course: return .green
        case .club: return .purple
        case .company: return .orange
        case .project: return .green
        case .other: return .gray
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
                                            await requestToJoinAsync(org)
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

    private func requestToJoinAsync(_ org: Organization) async {
        guard let orgId = org.id else { return }

        do {
            try await viewModel.requestToJoinOrganization(organizationId: orgId)
            await MainActor.run {
                AlertHelper.shared.showSuccess("申請已送出！等待審核。")
                dismiss()
            }
        } catch {
            print("❌ Error requesting to join organization: \(error)")
            await MainActor.run {
                AlertHelper.shared.showError("申請失敗: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Search Result Card

@available(iOS 17.0, *)
struct SearchResultCard: View {
    let organization: Organization
    let onRequest: () async -> Void
    @State private var isProcessing = false

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
                _Concurrency.Task {
                    guard !isProcessing else { return }
                    isProcessing = true
                    await onRequest()
                    // small delay to let state update
                    try? await _Concurrency.Task.sleep(nanoseconds: 80_000_000)
                    isProcessing = false
                }
            } label: {
                HStack {
                    if isProcessing { ProgressView().scaleEffect(0.8) }
                    Text("申請加入")
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                }
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
        case .course: return .green
        case .club: return .purple
        case .company: return .orange
        case .project: return .mint
        case .other: return .gray
        }
    }
}