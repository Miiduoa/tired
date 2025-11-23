import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct OrganizationDetailView: View {
    let organization: Organization

    @StateObject private var viewModel: OrganizationDetailViewModel
    @State private var selectedTab: DetailTab = .overview
    @State private var showingManageApps = false
    @State private var showingMembershipRequests = false

    enum DetailTab: String, CaseIterable {
        case overview = "簡介"
        case posts = "動態"
        case apps = "小應用"
    }

    init(organization: Organization) {
        self.organization = organization
        self._viewModel = StateObject(wrappedValue: OrganizationDetailViewModel(organization: organization))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with cover image
                ZStack(alignment: .bottomLeading) {
                    // Cover image
                    if let coverUrl = organization.coverUrl {
                        AsyncImage(url: URL(string: coverUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        .frame(height: 150)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 150)
                    }

                    // Avatar overlay
                    HStack(alignment: .bottom, spacing: 12) {
                        if let avatarUrl = organization.avatarUrl {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                avatarPlaceholder
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        } else {
                            avatarPlaceholder
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(organization.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)

                                if organization.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                }
                            }

                            Text(organization.type.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 2)
                        }
                        .padding(.bottom, 8)

                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 4) {
                    if viewModel.isMember {
                        Button {
                            viewModel.leaveOrganization()
                        } label: {
                            Text("退出組織")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appSecondaryBackground)
                                .cornerRadius(8)
                        }
                    } else {
                        Button {
                            viewModel.requestToJoinOrganization()
                        } label: {
                            Text(viewModel.isRequestPending ? "申請已送出" : "申請加入")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(viewModel.isRequestPending ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.isRequestPending)
                    }

                    if let statusMessage = viewModel.requestStatusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()

                // Tab selector
                Picker("視圖", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Divider()
                    .padding(.top, 8)

                // Tab content
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
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if viewModel.currentMembership?.hasPermission(.manageMembers) == true {
                        Button {
                            showingMembershipRequests = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }

                    if viewModel.currentMembership?.hasPermission(.manageApps) == true {
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
            MembershipRequestsView(organizationId: organization.id ?? "")
        }
    }

    private var avatarPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(organization.name.prefix(2)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
            )
    }
}

// MARK: - Overview Tab

@available(iOS 17.0, *)
struct OverviewTab: View {
    let organization: Organization
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("關於")
                    .font(.system(size: 16, weight: .semibold))

                if let description = organization.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text("暫無介紹")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            // My role
            if viewModel.isMember, let membership = viewModel.currentMembership {
                VStack(alignment: .leading, spacing: 8) {
                    Text("我的身份")
                        .font(.system(size: 16, weight: .semibold))

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text(membership.role.displayName)
                            .font(.system(size: 14))

                        if let title = membership.title {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(title)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Posts Tab

@available(iOS 17.0, *)
struct PostsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("組織動態")
                .font(.system(size: 16, weight: .semibold))

            if viewModel.posts.isEmpty {
                Text("暫無動態")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post)
                }
            }
        }
    }
}

// MARK: - Apps Tab

@available(iOS 17.0, *)
struct AppsTab: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小應用")
                .font(.system(size: 16, weight: .semibold))

            if viewModel.apps.isEmpty {
                Text("暫未啟用任何小應用")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(viewModel.apps) { app in
                    AppInstanceCard(app: app, organizationId: viewModel.organization.id ?? "")
                }
            }
        }
    }
}

// MARK: - Post Card View

@available(iOS 17.0, *)
struct PostCardView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Time
            Text(post.createdAt.formatShort())
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Content
            Text(post.contentText)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            // Actions
            HStack(spacing: 20) {
                Label("0", systemImage: "heart")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Label("0", systemImage: "bubble.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - App Instance Card

@available(iOS 17.0, *)
struct AppInstanceCard: View {
    let app: OrgAppInstance
    let organizationId: String

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                Image(systemName: iconForTemplate(app.templateKey))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name ?? app.templateKey.displayName)
                        .font(.system(size: 15, weight: .medium))

                    Text(descriptionForTemplate(app.templateKey))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch app.templateKey {
        case .taskBoard:
            TaskBoardView(appInstance: app, organizationId: organizationId)
        case .eventSignup:
            EventSignupView(appInstance: app, organizationId: organizationId)
        case .resourceList:
            ResourceListView(appInstance: app, organizationId: organizationId)
        }
    }

    private func iconForTemplate(_ key: OrgAppTemplateKey) -> String {
        switch key {
        case .taskBoard: return "checklist"
        case .eventSignup: return "calendar.badge.plus"
        case .resourceList: return "folder"
        }
    }

    private func descriptionForTemplate(_ key: OrgAppTemplateKey) -> String {
        switch key {
        case .taskBoard: return "查看和管理組織任務"
        case .eventSignup: return "查看活動並報名"
        case .resourceList: return "瀏覽共享資源"
        }
    }
}
