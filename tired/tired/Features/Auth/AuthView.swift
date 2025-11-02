import SwiftUI
import Combine

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isSignUp = false
    @State private var showPasswordReset = false
    
    var body: some View {
        ZStack {
            // 動態背景漸層（呼吸效果）
            ZStack {
                TTokens.gradientPrimary
                    .ignoresSafeArea()
                
                // 浮動粒子效果
                FloatingParticlesView()
                    .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: TTokens.spacingXL) {
                    Spacer(minLength: TTokens.spacingXXL)
                    
                    // Logo 和標題區
                    headerSection
                    
                    // 登入表單卡片
                    formCard
                    
                    // 第三方登入按鈕
                    socialLoginSection
                    
                    // 帳號安全選項
                    if !isSignUp {
                        securityOptionsSection
                    }
                    
                    Spacer(minLength: TTokens.spacingXL)
                }
                .padding(.horizontal, TTokens.spacingLG)
            }
        }
        .alert(item: $authService.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("確定")) {
                authService.activeAlert = nil
            })
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(email: $email)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: TTokens.spacingMD) {
            // Logo/Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            
            // 標題
            VStack(spacing: TTokens.spacingXS) {
                Text("歡迎使用 Tired")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text(isSignUp ? "建立新帳號開始使用" : "登入以繼續")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.bottom, TTokens.spacingLG)
    }
    
    // MARK: - Form Card
    
    private var formCard: some View {
        VStack(spacing: TTokens.spacingLG) {
            // 表單欄位
            VStack(spacing: TTokens.spacingMD) {
                // 電子郵件
                AuthTextField(
                    title: "電子郵件",
                    text: $email,
                    placeholder: "your@email.com",
                    keyboardType: .emailAddress,
                    icon: "envelope.fill"
                )
                
                // 密碼
                AuthSecureField(
                    title: "密碼",
                    text: $password,
                    placeholder: "至少 6 個字元"
                )
                
                // 顯示名稱（僅註冊時）
                if isSignUp {
                    AuthTextField(
                        title: "顯示名稱",
                        text: $displayName,
                        placeholder: "您的名稱",
                        icon: "person.fill"
                    )
                }
            }
            .padding(TTokens.spacingLG)
            
            Divider()
                .padding(.horizontal, TTokens.spacingLG)
            
            // 主要操作按鈕
            VStack(spacing: TTokens.spacingMD) {
                Button(action: {
                    HapticFeedback.medium()
                    handleSubmit()
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text(isSignUp ? "建立帳號" : "登入")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: TTokens.touchTargetComfortable)
                }
                .fluidButton(gradient: isFormValid ? TTokens.gradientPrimary : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .disabled(!isFormValid || authService.isLoading)
                .animation(.easeInOut(duration: 0.2), value: isFormValid)
                
                // 切換登入/註冊
                Button(action: { 
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3)) { isSignUp.toggle() } 
                }) {
                    HStack(spacing: TTokens.spacingXS) {
                        Text(isSignUp ? "已有帳號？" : "還沒有帳號？")
                            .foregroundStyle(.secondary)
                        Text(isSignUp ? "登入" : "立即註冊")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tint)
                    }
                    .font(.subheadline)
                    .padding(.vertical, TTokens.spacingSM)
                }
            }
            .padding(.horizontal, TTokens.spacingLG)
            .padding(.bottom, TTokens.spacingLG)
        }
        .glassEffect(intensity: 0.7)
        .shadow(color: TTokens.shadowElevated.color, radius: TTokens.shadowElevated.radius, y: TTokens.shadowElevated.y)
    }
    
    // MARK: - Social Login Section
    
    private var socialLoginSection: some View {
        VStack(spacing: TTokens.spacingMD) {
            // 分隔線
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                Text("或使用")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, TTokens.spacingSM)
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
            }
            
            // 第三方登入按鈕
            VStack(spacing: TTokens.spacingSM) {
                // Apple Sign In
                SocialLoginButton(
                    title: "使用 Apple 登入",
                    icon: "applelogo",
                    backgroundColor: .black,
                    foregroundColor: .white,
                    action: { authService.signInWithApple() },
                    disabled: authService.isLoading
                )
                
                // Google Sign In
                SocialLoginButton(
                    title: "使用 Google 登入",
                    icon: "globe",
                    backgroundColor: .white,
                    foregroundColor: .primary,
                    action: { authService.signInWithGoogle() },
                    disabled: authService.isLoading
                )
            }
        }
        .padding(.horizontal, TTokens.spacingLG)
    }
    
    // MARK: - Security Options
    
    private var securityOptionsSection: some View {
        VStack(spacing: TTokens.spacingSM) {
            Button(action: { showPasswordReset = true }) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.caption)
                    Text("忘記密碼？")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && password.count >= 6 && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleSubmit() {
        guard !authService.isLoading else { return }
        
        if isSignUp {
            authService.signUpWithEmail(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? email : displayName
            )
        } else {
            authService.signInWithEmail(email: email, password: password)
        }
    }
}

// MARK: - Auth Text Field

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var icon: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingXS) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: TTokens.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(keyboardType == .emailAddress ? .emailAddress : .none)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .font(.body)
            }
            .padding(TTokens.spacingMD)
            .background(Color.bg2, in: RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous)
                    .strokeBorder(Color.separator, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Auth Secure Field

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingXS) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: TTokens.spacingSM) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.body)
                
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding(TTokens.spacingMD)
            .background(Color.bg2, in: RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous)
                    .strokeBorder(Color.separator, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Social Login Button

private struct SocialLoginButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    let disabled: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: TTokens.spacingMD) {
                Image(systemName: icon)
                    .font(.headline)
                
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TTokens.spacingMD)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
            .foregroundStyle(foregroundColor)
            .opacity(disabled ? 0.6 : 1.0)
        }
        .disabled(disabled)
        .overlay {
            RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous)
                .strokeBorder(foregroundColor.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Password Reset View

private struct PasswordResetView: View {
    @Binding var email: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TTokens.spacingXL) {
                VStack(spacing: TTokens.spacingMD) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.tint)
                        .padding(.bottom, TTokens.spacingSM)
                    
                    Text("重設密碼")
                        .font(.title2.weight(.bold))
                    
                    Text("我們將發送密碼重設連結到您的電子郵件")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, TTokens.spacingXXL)
                
                VStack(spacing: TTokens.spacingMD) {
                    AuthTextField(
                        title: "電子郵件",
                        text: $email,
                        placeholder: "your@email.com",
                        keyboardType: .emailAddress,
                        icon: "envelope.fill"
                    )
                    
                    Button(action: {
                        authService.resetPassword(email: email)
                        dismiss()
                    }) {
                        Text("發送重設連結")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TTokens.spacingMD)
                            .background(email.contains("@") ? AnyShapeStyle(TTokens.gradientPrimary) : AnyShapeStyle(Color.gray.opacity(0.3)))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
                    }
                    .disabled(!email.contains("@") || authService.isLoading)
                }
                .padding(TTokens.spacingLG)
                .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
                
                Spacer()
            }
            .padding(TTokens.spacingLG)
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("重設密碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
