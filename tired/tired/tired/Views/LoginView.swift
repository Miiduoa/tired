import SwiftUI
import UIKit // For UIWindowScene and UIViewController
import FirebaseAuth // For Auth.auth().currentUser?.uid

@available(iOS 17.0, *)
struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Helper to get root view controller
    private var rootViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppDesignSystem.paddingLarge) {
                    header
                    formCard
                    securityFooter
                }
                .padding(.horizontal, AppDesignSystem.paddingLarge)
                .padding(.vertical, AppDesignSystem.paddingLarge)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            HStack(spacing: AppDesignSystem.paddingSmall) {
                Image(systemName: "sparkles")
                    .font(.title2.bold())
                    .foregroundColor(AppDesignSystem.accentColor)
                Text("Tired")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                Text("多身份任務中樞")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                Text("從學校、工作到社團，用同一個節奏管理待辦與活動。")
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, AppDesignSystem.paddingMedium)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            toggleButtons
            inputFields
            errorMessageView
            submitButton
            divider
            googleSignInButton
            toggleModeButton
        }
        .standardCard()
    }
    
    private var toggleButtons: some View {
        HStack(spacing: 0) {
            ForEach([(false, "登入"), (true, "註冊")], id: \.0) { tuple in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isSignUp = tuple.0
                        errorMessage = nil
                    }
                } label: {
                    Text(tuple.1)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(tuple.0 == isSignUp ? AppDesignSystem.accentColor : Color.clear)
                        .foregroundColor(tuple.0 == isSignUp ? .white : .primary)
                        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.appPrimaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusSmall + 4)
    }
    
    @ViewBuilder
    private var inputFields: some View {
        if isSignUp {
            TextField("姓名", text: $name)
                .textFieldStyle(StandardTextFieldStyle(icon: "person"))
                .textContentType(.name)
                .autocapitalization(.words)
        }

        TextField("信箱", text: $email)
            .textFieldStyle(StandardTextFieldStyle(icon: "envelope"))
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)

        SecureField("密碼", text: $password)
            .textFieldStyle(StandardTextFieldStyle(icon: "lock"))
            .textContentType(isSignUp ? .newPassword : .password)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(.red)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    Text(error)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.red)
                    if error.contains("已被使用") || error.contains("already in use") {
                        Button {
                            withAnimation { isSignUp = false; errorMessage = nil }
                        } label: {
                            Text("切換到登入模式")
                                .font(AppDesignSystem.captionFont.weight(.semibold))
                                .foregroundColor(AppDesignSystem.accentColor)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private var submitButton: some View {
        Button(action: handleAuth) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(isSignUp ? "建立帳號" : "進入任務中心")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: !isLoading && isFormValid))
        .disabled(isLoading || !isFormValid)
    }
    
    private var divider: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
            Text("或")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }
    
    private var googleSignInButton: some View {
        Button(action: handleGoogleSignIn) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                Text("使用 Google 登入")
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isLoading)
    }
    
    private var toggleModeButton: some View {
        Button {
            withAnimation(.spring()) {
                isSignUp.toggle()
                errorMessage = nil
            }
        } label: {
            Text(isSignUp ? "已有帳號？直接登入" : "沒有帳號？立即註冊")
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(AppDesignSystem.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, AppDesignSystem.paddingSmall)
    }
    
    private var securityFooter: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            Image(systemName: "lock.fill")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("所有登入皆經過加密傳輸，僅在你授權後同步到多身份任務中心。")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !name.isEmpty && !email.isEmpty && !password.isEmpty && password.count >= 6
        }
        return !email.isEmpty && !password.isEmpty
    }

    private func handleAuth() {
        errorMessage = nil
        isLoading = true

        _Concurrency.Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password, name: name)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    let nsError = error as NSError
                    if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        errorMessage = description
                        // 優化：優先檢查錯誤代碼 17007 (FIRAuthErrorCodeEmailAlreadyInUse)
                        if nsError.code == 17007 { 
                            withAnimation { isSignUp = false }
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    isLoading = false
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        errorMessage = nil
        isLoading = true

        guard let presentingVC = rootViewController else {
            errorMessage = "無法獲取視圖控制器"
            isLoading = false
            return
        }

        _Concurrency.Task {
            do {
                try await authService.signInWithGoogle(presentingViewController: presentingVC)
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    let nsError = error as NSError
                    if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        errorMessage = description
                    } else {
                        errorMessage = "Google 登入失敗：\(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthService())
    }
}
