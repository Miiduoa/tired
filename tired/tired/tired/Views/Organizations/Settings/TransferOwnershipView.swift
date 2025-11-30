import SwiftUI
import FirebaseAuth

@available(iOS 17.0, *)
struct TransferOwnershipView: View {
    let organization: Organization
    @ObservedObject var viewModel: OrganizationDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var memberViewModel: MemberManagementViewModel
    @State private var selectedMember: MemberWithProfile?
    @State private var isTransferring = false
    @State private var showingConfirmation = false
    
    init(organization: Organization, viewModel: OrganizationDetailViewModel) {
        self.organization = organization
        self.viewModel = viewModel
        _memberViewModel = StateObject(wrappedValue: MemberManagementViewModel(organization: organization))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                Form {
                    Section {
                        Text("選擇要轉移所有權的成員。轉移後，您將成為管理員，選中的成員將成為組織擁有者。")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("說明")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    
                    Section {
                        if memberViewModel.isLoading {
                            ProgressView("載入成員中...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if memberViewModel.members.isEmpty {
                            Text("沒有可轉移的成員")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(memberViewModel.members.filter { member in
                                // 排除當前用戶
                                member.membership.userId != Auth.auth().currentUser?.uid
                            }) { member in
                                Button {
                                    selectedMember = member
                                    showingConfirmation = true
                                } label: {
                                    HStack {
                                        // Avatar
                                        if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.secondary.opacity(0.2))
                                            }
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.secondary.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Text(String(member.displayName.prefix(1)).uppercased())
                                                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                                                        .foregroundColor(.secondary)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(member.displayName)
                                                .font(AppDesignSystem.bodyFont.weight(.medium))
                                                .foregroundColor(.primary)
                                            
                                            // 顯示角色
                                            let roleNames = member.membership.roleIds.compactMap { roleId in
                                                organization.roles.first { $0.id == roleId }?.name
                                            }
                                            if !roleNames.isEmpty {
                                                Text(roleNames.joined(separator: ", "))
                                                    .font(AppDesignSystem.captionFont)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedMember?.id == member.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppDesignSystem.accentColor)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                                .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        Text("選擇新擁有者")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                .background(Color.clear)
            }
            .navigationTitle("轉移所有權")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
            }
            .confirmationDialog("確認轉移所有權", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("確認轉移", role: .destructive) {
                    transferOwnership()
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let member = selectedMember {
                    Text("您確定要將組織所有權轉移給 \(member.displayName) 嗎？轉移後，您將成為管理員，\(member.displayName) 將成為組織擁有者。此操作無法撤銷。")
                }
            }
            .overlay {
                if isTransferring {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("轉移中...")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func transferOwnership() {
        guard let member = selectedMember,
              let orgId = organization.id,
              let fromUserId = Auth.auth().currentUser?.uid else {
            ToastManager.shared.showToast(message: "轉移失敗：缺少必要信息", type: .error)
            return
        }
        
        let toUserId = member.membership.userId
        
        isTransferring = true
        
        _Concurrency.Task {
            do {
                try await OrganizationService().transferOwnership(
                    organizationId: orgId,
                    fromUserId: fromUserId,
                    toUserId: toUserId
                )
                
                await MainActor.run {
                    isTransferring = false
                    ToastManager.shared.showToast(message: "所有權已成功轉移", type: .success)
                    // 刷新組織數據
                    _Concurrency.Task {
                        await viewModel.fetchOrganization()
                    }
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isTransferring = false
                    ToastManager.shared.showToast(message: "轉移失敗：\(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}

