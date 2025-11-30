import SwiftUI

@available(iOS 17.0, *)
struct OrganizationSettingsView: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditOrg = false
    @State private var showingManageApps = false
    @State private var showingMemberManagement = false
    @State private var showingRoleManagement = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTransferOwnership = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                List {
                    // 基本信息
                    if viewModel.canEditOrgInfo {
                        Section {
                            Button {
                                showingEditOrg = true
                            } label: {
                                HStack {
                                    Label("編輯組織信息", systemImage: "pencil")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                        } header: {
                            Text("組織信息")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 成員管理
                    if viewModel.canManageMembers {
                        Section {
                            Button {
                                showingMemberManagement = true
                            } label: {
                                HStack {
                                    Label("成員管理", systemImage: "person.3.fill")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                        } header: {
                            Text("成員")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 角色管理
                    if viewModel.canChangeRoles {
                        Section {
                            Button {
                                showingRoleManagement = true
                            } label: {
                                HStack {
                                    Label("角色管理", systemImage: "shield.fill")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                        } header: {
                            Text("權限")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 小應用管理
                    if viewModel.canManageApps {
                        Section {
                            Button {
                                showingManageApps = true
                            } label: {
                                HStack {
                                    Label("管理小應用", systemImage: "slider.horizontal.3")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                        } header: {
                            Text("應用")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    // 所有權管理
                    if viewModel.canDeleteOrganization {
                        Section {
                            Button {
                                showingTransferOwnership = true
                            } label: {
                                HStack {
                                    Label("轉移所有權", systemImage: "arrow.triangle.2.circlepath")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.primary)
                            
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Label("刪除組織", systemImage: "trash")
                                    }
                                }
                            }
                            .disabled(isDeleting)
                        } header: {
                            Text("所有權管理")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        } footer: {
                            Text("轉移所有權將把組織的擁有者權限轉移給其他成員。刪除組織將永久刪除所有相關數據，包括成員、角色、任務和活動。此操作無法撤銷。")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .background(Color.clear)
            }
            .navigationTitle("組織設置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .primary))
                }
            }
            .sheet(isPresented: $showingEditOrg) {
                EditOrganizationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingManageApps) {
                ManageAppsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingMemberManagement) {
                if let org = viewModel.organization {
                    MemberManagementView(organization: org)
                }
            }
            .sheet(isPresented: $showingRoleManagement) {
                if let org = viewModel.organization {
                    RoleManagementView(organization: org)
                }
            }
            .sheet(isPresented: $showingTransferOwnership) {
                if let org = viewModel.organization {
                    TransferOwnershipView(organization: org, viewModel: viewModel)
                }
            }
            .confirmationDialog("刪除組織", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("刪除", role: .destructive) {
                    deleteOrganization()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("您確定要刪除此組織嗎？此操作將永久刪除所有相關數據，包括成員、角色、任務和活動。此操作無法撤銷。")
            }
        }
    }
    
    private func deleteOrganization() {
        isDeleting = true
        
        _Concurrency.Task {
            let success = await viewModel.deleteOrganizationAsync()
            
            await MainActor.run {
                isDeleting = false
                if success {
                    dismiss()
                    // 導航回組織列表（這需要通過環境變量或通知來實現）
                }
            }
        }
    }
}

