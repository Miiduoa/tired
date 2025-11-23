import SwiftUI

// MARK: - My Organizations List View

@available(iOS 17.0, *)
struct MyOrganizationsListView: View {
    @StateObject private var viewModel = OrganizationsViewModel()

    var body: some View {
        List {
            if viewModel.myMemberships.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("還沒有加入任何組織")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("前往「組織」頁面探索並加入組織")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.myMemberships) { membershipWithOrg in
                    if let org = membershipWithOrg.organization {
                        NavigationLink(destination: OrganizationDetailView(organization: org)) {
                            HStack(spacing: 12) {
                                // Avatar
                                if let avatarUrl = org.avatarUrl {
                                    AsyncImage(url: URL(string: avatarUrl)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        orgAvatarPlaceholder(name: org.name)
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    orgAvatarPlaceholder(name: org.name)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(org.name)
                                            .font(.system(size: 15, weight: .medium))
                                        if org.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 12))
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        Text(membershipWithOrg.membership.role.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)

                                        Text(org.type.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的組織")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func orgAvatarPlaceholder(name: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
