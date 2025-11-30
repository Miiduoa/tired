import SwiftUI

@available(iOS 17.0, *)
struct AddTaskOwnershipView: View {
    @Binding var selectedOrgId: String?
    @Binding var assigneeUserId: String?
    @Binding var assigneeOptions: [AssigneeOption]
    @ObservedObject var orgViewModel: OrganizationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("歸屬與負責")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Picker("任務歸屬", selection: $selectedOrgId) {
                Text("個人任務").tag(nil as String?)
                ForEach(orgViewModel.myMemberships, id: \.id) { membershipWithOrg in
                    if let org = membershipWithOrg.organization, let orgId = org.id {
                        Text(org.name).tag(orgId as String?)
                    }
                }
            }
            .pickerStyle(.navigationLink)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("負責人")
                        .font(AppDesignSystem.bodyFont)
                    Spacer()
                    if let selected = assigneeOptions.first(where: { $0.id == assigneeUserId }) {
                        Text(selected.name)
                            .foregroundColor(.primary)
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                    } else if assigneeOptions.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("尚未選擇")
                            .foregroundColor(.secondary)
                    }
                }
                
                if assigneeOptions.isEmpty {
                    Text("若未選擇會自動指派給自己")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(assigneeOptions) { option in
                                Button {
                                    assigneeUserId = option.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: assigneeUserId == option.id ? "checkmark.circle.fill" : "person.fill")
                                            .foregroundColor(assigneeUserId == option.id ? AppDesignSystem.accentColor : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.name)
                                                .font(.system(size: 13, weight: .semibold))
                                            if let detail = option.detail {
                                                Text(detail)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(assigneeUserId == option.id ? AppDesignSystem.accentColor.opacity(0.15) : Color.appSecondaryBackground.opacity(0.5))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }
}
