
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    
    var body: some View {
        List {
            if let user = authService.currentUser {
                // 使用者資訊區
                userInfoSection(user: user)
                
                // 帳號設定
                accountSettingsSection(user: user)
                
                // 安全選項
                securitySection
                
                // 登出與刪除帳號
                actionSection
            } else {
                Section {
                    VStack(spacing: TTokens.spacingMD) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("尚未登入")
                            .font(.headline)
                        Text("請先登入以查看帳號資訊")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TTokens.spacingXL)
                }
            }
        }
        .navigationTitle("帳號")
        .alert(item: $authService.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("確定")) {
                authService.activeAlert = nil
            })
        }
        .confirmationDialog("確定要登出嗎？", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("登出", role: .destructive) {
                authService.signOut()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("登出後需要重新登入才能使用應用程式")
        }
        .confirmationDialog("刪除帳號", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("刪除帳號", role: .destructive) {
                // TODO: 實現刪除帳號功能
                authService.activeAlert = .init(kind: .info, message: "刪除帳號功能開發中")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作無法復原，所有資料將永久刪除")
        }
    }
    
    // MARK: - User Info Section
    
    private func userInfoSection(user: User) -> some View {
        Section {
            HStack(spacing: TTokens.spacingMD) {
                // 頭像
                ZStack {
                    Circle()
                        .fill(TTokens.gradientPrimary)
                        .frame(width: 64, height: 64)
                    
                    if !user.displayName.isEmpty {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
                
                // 使用者資訊
                VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                    Text(user.displayName.isEmpty ? "未設定名稱" : user.displayName)
                        .font(.headline)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // 驗證狀態標籤
                    VerificationStatusBadge(status: user.verificationStatus)
                }
                
                Spacer()
            }
            .padding(.vertical, TTokens.spacingXS)
        } header: {
            Text("帳號資訊")
        }
    }
    
    // MARK: - Account Settings Section
    
    private func accountSettingsSection(user: User) -> some View {
        Section {
            // 個人資料
            NavigationLink(destination: Text("個人資料編輯")) {
                Label {
                    VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                        Text("個人資料")
                        if user.displayName.isEmpty {
                            Text("尚未設定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "person.text.rectangle.fill")
                }
            }
            
            // 顯示名稱
            HStack {
                Label("顯示名稱", systemImage: "person.fill")
                Spacer()
                Text(user.displayName.isEmpty ? "未設定" : user.displayName)
                    .foregroundStyle(.secondary)
            }
            
            // 電子郵件
            HStack {
                Label("電子郵件", systemImage: "envelope.fill")
                Spacer()
                Text(user.email)
                    .foregroundStyle(.secondary)
            }
            
            // 手機號碼
            if let phone = user.phoneNumber {
                HStack {
                    Label("手機號碼", systemImage: "phone.fill")
                    Spacer()
                    Text(phone)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(action: {}) {
                    Label("新增手機號碼", systemImage: "phone.badge.plus")
                }
            }
        } header: {
            Text("帳號設定")
        }
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        Section {
            // 密碼管理
            Button(action: {}) {
                Label("變更密碼", systemImage: "key.fill")
            }
            
            // 電子郵件驗證
            if let user = authService.currentUser {
                Button(action: {
                    if user.verificationStatus == .verified {
                        authService.refreshEmailVerificationStatus()
                    } else {
                        authService.sendEmailVerification()
                    }
                }) {
                    HStack {
                        Label("電子郵件驗證", systemImage: "envelope.badge.fill")
                        Spacer()
                        if user.verificationStatus == .verified {
                            Label("已驗證", systemImage: "checkmark.circle.fill")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("待驗證")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                if user.verificationStatus != .verified {
                    Button(action: { authService.sendEmailVerification() }) {
                        HStack {
                            Label("重新發送驗證郵件", systemImage: "arrow.clockwise")
                            Spacer()
                        }
                    }
                    .font(.caption)
                }
            }
            
            // 隱私設定
            NavigationLink(destination: Text("隱私設定")) {
                Label("隱私設定", systemImage: "hand.raised.fill")
            }
        } header: {
            Text("安全與隱私")
        }
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        Section {
            // 登出按鈕
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("登出", systemImage: "arrow.right.square")
                    Spacer()
                }
            }
            
            // 刪除帳號（隱藏較深）
            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("刪除帳號")
                        .font(.caption)
                    Spacer()
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Verification Status Badge

private struct VerificationStatusBadge: View {
    let status: UserVerificationStatus
    
    var body: some View {
        HStack(spacing: TTokens.spacingXS) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.title)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, TTokens.spacingSM)
        .padding(.vertical, TTokens.spacingXS)
        .background(status.color.opacity(0.15), in: Capsule())
        .foregroundStyle(status.color)
    }
}
