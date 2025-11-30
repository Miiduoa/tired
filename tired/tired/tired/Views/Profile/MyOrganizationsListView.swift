import SwiftUI

// MARK: - My Organizations List View

@available(iOS 17.0, *)
struct MyOrganizationsListView: View {
    @StateObject private var viewModel = OrganizationsViewModel()

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            List {
                if viewModel.myMemberships.isEmpty {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("還沒有加入任何組織")
                            .font(AppDesignSystem.headlineFont)
                            .foregroundColor(.primary)
                        Text("前往「身份」頁面探索並加入組織")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppDesignSystem.paddingLarge)
                    .glassmorphicCard() // Apply glassmorphic to empty state
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingLarge, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))

                } else {
                    ForEach(viewModel.myMemberships, id: \.id) { membershipWithOrg in
                        if let org = membershipWithOrg.organization {
                            NavigationLink(destination: OrganizationDetailView(organizationId: org.id ?? "")) {
                                OrganizationCard(
                                    organization: org,
                                    membership: membershipWithOrg.membership
                                )
                            }
                            .buttonStyle(.plain) // Ensure NavigationLink acts as a plain button
                            .listRowBackground(Color.clear) // Make list row transparent
                        }
                    }
                }
            }
            .listStyle(.plain) // Use plain list style for custom backgrounds
            .navigationTitle("我的組織")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
    }
}