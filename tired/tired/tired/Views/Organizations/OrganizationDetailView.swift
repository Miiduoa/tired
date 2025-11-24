import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct OrganizationDetailView: View {
    @StateObject private var viewModel: OrganizationDetailViewModel
    
    @State private var selectedTab: DetailTab = .overview
    @State private var showingManageApps = false
    @State private var showingMembershipRequests = false
    @State private var showingRoleManagement = false

    enum DetailTab: String, CaseIterable {
        case overview = "簡介", posts = "動態", apps = "小應用"
    }

    init(organizationId: String) {
        _viewModel = StateObject(wrappedValue: OrganizationDetailViewModel(organizationId: organizationId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("正在載入組織...")
            } else if let organization = viewModel.organization {
                content(for: organization)
                    .background(
                        NavigationLink(
                            destination: RoleManagementView(organization: organization),
                            isActive: $showingRoleManagement
                        ) { EmptyView() }
                    )
            } else {
                Text("無法載入組織資訊")
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if viewModel.canChangeRoles {
                        Button {
                            showingRoleManagement = true
                        } label: {
                            Image(systemName: "shield.righthalf.filled")
                        }
                    }
                    
                    if viewModel.canManageMembers {
                        Button {
                            showingMembershipRequests = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }

                    if viewModel.canManageApps {
                        Button {
                            showingManageApps = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingManageApps) {
            ManageAppsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingMembershipRequests) {
            if let orgId = viewModel.organization?.id {
                MembershipRequestsView(organizationId: orgId)
            }
        }
    }

    private func content(for organization: Organization) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                header(for: organization)
                
                actionButtons
                    .padding()
                
                tabSelector
                
                Divider().padding(.top, 8)
                
                tabContent(for: organization)
                    .padding()
            }
        }
    }

    private func header(for organization: Organization) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image
            if let coverUrl = organization.coverUrl {
                AsyncImage(url: URL(string: coverUrl)) { $0.resizable().scaledToFill() }
                placeholder: { coverPlaceholder }
                .frame(height: 150).clipped()
            } else {
                coverPlaceholder
            }

            // Avatar and Title overlay
            HStack(alignment: .bottom, spacing: 12) {
                if let avatarUrl = organization.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { $0.resizable().scaledToFill() }
                    placeholder: { avatarPlaceholder(for: organization) }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 3))
                } else {
                    avatarPlaceholder(for: organization)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(organization.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white).shadow(radius: 2)

                        if organization.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue).font(.system(size: 16))
                        }
                    }
                    Text(organization.type.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9)).shadow(radius: 2)
                }
                .padding(.bottom, 8)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 4) {
            if viewModel.isMember {
                Button { viewModel.leaveOrganization() } label: {
                    Text("退出組織")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary).frame(maxWidth: .infinity)
                        .padding(.vertical, 10).background(Color.appSecondaryBackground)
                        .cornerRadius(8)
                }
            } else {
                Button { viewModel.requestToJoinOrganization() } label: {
                    Text(viewModel.isRequestPending ? "申請已送出" : "申請加入")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.isRequestPending ? Color.gray : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(viewModel.isRequestPending)
            }
            if let statusMessage = viewModel.requestStatusMessage {
                Text(statusMessage).font(.caption).foregroundColor(.secondary).padding(.top, 4)
            }
        }
    }

    private var tabSelector: some View {
        Picker("視圖", selection: $selectedTab) {
            ForEach(DetailTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private func tabContent(for organization: Organization) -> some View {
        VStack(spacing: 16) {
            switch selectedTab {
            case .overview:
                OverviewTab(organization: organization, viewModel: viewModel)
            case .posts:
                PostsTab(viewModel: viewModel)
            case .apps:
                AppsTab(viewModel: viewModel)
            }
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 150)
    }

    private func avatarPlaceholder(for organization: Organization) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(Text(String(organization.name.prefix(2)).uppercased()).font(.system(size: 28, weight: .bold)).foregroundColor(.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 3))
    }
}

// MARK: - Overview Tab
@available(iOS 17.0, *)
struct OverviewTab: View {
    let organization: Organization
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("關於").font(.system(size: 16, weight: .semibold))
                Text(organization.description ?? "暫無介紹")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                    .italic(organization.description == nil)
            }
            if viewModel.isMember, let membership = viewModel.currentMembership {
                VStack(alignment: .leading, spacing: 8) {
                    Text("我的身份").font(.system(size: 16, weight: .semibold))
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.blue)
                        
                        let roleNames = membership.roleIds.compactMap { roleId in
                            organization.roles.first { $0.id == roleId }?.name
                        }
                        
                        if roleNames.isEmpty {
                            Text("成員").font(.system(size: 14))
                        } else {
                            ForEach(roleNames, id: \.self) { name in
                                Text(name)
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }

                        if let title = membership.title {
                            Text("·").foregroundColor(.secondary)
                            Text(title).font(.system(size: 14)).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
// ... Rest of the subviews (PostsTab, AppsTab, etc.) remain the same ...
