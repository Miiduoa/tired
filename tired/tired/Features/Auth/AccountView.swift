
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showChangePasswordSheet = false
    @State private var showAddPhoneSheet = false
    @State private var showDeletePasswordSheet = false
    @State private var deletePasswordInput: String = ""
    
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
                if authService.currentUser?.provider == "password" {
                    showDeletePasswordSheet = true
                } else {
                    authService.deleteAccount()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作無法復原，所有資料將永久刪除")
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            NavigationStack { ChangePasswordSheet { oldPwd, newPwd in
                authService.changePassword(currentPassword: oldPwd, newPassword: newPwd)
            } onClose: {
                showChangePasswordSheet = false
            } }
            .presentationDetents([.height(320), .medium])
        }
        .sheet(isPresented: $showAddPhoneSheet) {
            NavigationStack { AddPhoneSheet()
                    .environmentObject(authService)
            }
            .presentationDetents([.height(360), .medium])
        }
        .sheet(isPresented: $showDeletePasswordSheet) {
            NavigationStack {
                DeleteAccountSheet(password: $deletePasswordInput) {
                    authService.deleteAccount(password: deletePasswordInput)
                } onClose: {
                    deletePasswordInput = ""
                    showDeletePasswordSheet = false
                }
            }
            .presentationDetents([.height(260), .medium])
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
                Button(action: { showAddPhoneSheet = true }) {
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
            Button(action: { showChangePasswordSheet = true }) {
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

// MARK: - Sheets

private struct ChangePasswordSheet: View {
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    let onSubmit: (_ old: String, _ new: String) -> Void
    let onClose: () -> Void
    
    var body: some View {
        Form {
            Section("變更密碼") {
                SecureField("目前密碼", text: $oldPassword)
                    .textContentType(.password)
                SecureField("新密碼（至少 6 碼）", text: $newPassword)
                    .textContentType(.newPassword)
            }
            Section {
                Button("更新密碼") { onSubmit(oldPassword, newPassword) }
                    .disabled(oldPassword.isEmpty || newPassword.count < 6)
                Button("取消", role: .cancel) { onClose() }
            }
        }
        .navigationTitle("變更密碼")
    }
}

private struct AddPhoneSheet: View {
    @EnvironmentObject private var authService: AuthService
    @State private var phoneNumber: String = ""
    @State private var code: String = ""
    @State private var sent: Bool = false
    
    var body: some View {
        Form {
            Section(sent ? "輸入簡訊驗證碼" : "新增手機號碼") {
                if !sent {
                    TextField("例如：+886912345678", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } else {
                    SecureField("6 位數驗證碼", text: $code)
                        .keyboardType(.numberPad)
                }
            }
            Section {
                if !sent {
                    Button("傳送驗證碼") {
                        authService.startPhoneVerification(phoneNumber: phoneNumber)
                        sent = true
                    }
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("驗證手機號碼") {
                        authService.verifyPhone(with: code)
                    }
                    .disabled(code.count < 6)
                }
            }
        }
        .navigationTitle("新增手機號碼")
    }
}

private struct DeleteAccountSheet: View {
    @Binding var password: String
    let onDelete: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        Form {
            Section("為安全起見，請重新輸入密碼") {
                SecureField("帳號密碼", text: $password)
                    .textContentType(.password)
            }
            Section {
                Button("永久刪除帳號", role: .destructive) { onDelete() }
                    .disabled(password.isEmpty)
                Button("取消", role: .cancel) { onClose() }
            }
        }
        .navigationTitle("刪除帳號")
    }
}
