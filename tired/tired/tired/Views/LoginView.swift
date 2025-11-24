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
            // Background with modern glass effect feel
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
            
            ParticleView() // Optional: For dynamic background visual interest

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppDesignSystem.paddingLarge * 2) {
                    Spacer()
                        .frame(minHeight: 40) // Give some top spacing

                    // Logo / Title
                    VStack(spacing: AppDesignSystem.paddingSmall) {
                        Image(systemName: "bed.double.fill") // Example logo icon
                            .font(.system(size: 60))
                            .foregroundColor(AppDesignSystem.accentColor)

                        Text("Tired App")
                            .font(AppDesignSystem.titleFont)
                            .foregroundColor(.primary)

                        Text("多身份任務管理系統")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    }

                    // Login/Signup Form Card
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        if isSignUp {
                            TextField("姓名", text: $name)
                                .textFieldStyle(FrostedTextFieldStyle())
                                .textContentType(.name)
                        }

                        TextField("信箱", text: $email)
                            .textFieldStyle(FrostedTextFieldStyle())
                            .textContentType(.emailAddress)
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
#endif

                        SecureField("密碼", text: $password)
                            .textFieldStyle(FrostedTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)

                        // Error Message
                        if let error = errorMessage {
                            VStack(spacing: AppDesignSystem.paddingSmall) {
                                Text(error)
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)

                                // If "email in use" error, suggest switching to sign-in
                                if error.contains("已被使用") || error.contains("already in use") {
                                    Button {
                                        withAnimation {
                                            isSignUp = false
                                            errorMessage = nil
                                        }
                                    } label: {
                                        Text("切換到登入模式")
                                            .font(AppDesignSystem.captionFont.weight(.medium))
                                            .foregroundColor(AppDesignSystem.accentColor)
                                            .underline()
                                    }
                                }
                            }
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                        }

                        // Main Auth Button
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white) // Ensure visibility on accent background
                                } else {
                                    Text(isSignUp ? "註冊" : "登入")
                                }
                            }
                        }
                        .buttonStyle(GlassmorphicButtonStyle(textColor: .white)) // Custom text color for primary action
                        .disabled(isLoading || !isFormValid)
                        
                        // Separator
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("或")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppDesignSystem.paddingSmall)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, AppDesignSystem.paddingSmall)

                        // Google Sign In Button
                        Button(action: handleGoogleSignIn) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(AppDesignSystem.bodyFont.weight(.medium))
                                Text("使用 Google 登入")
                            }
                        }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, textColor: .primary)) // Slightly different material/color
                        .disabled(isLoading)

                        // Toggle Sign Up / Login Mode
                        Button {
                            withAnimation(.spring()) {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            Text(isSignUp ? "已有帳號？登入" : "沒有帳號？註冊")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(AppDesignSystem.accentColor)
                        }
                    }
                    .padding(AppDesignSystem.paddingLarge)
                    .glassmorphicCard() // Apply glassmorphic effect to the form container
                    .padding(.horizontal, AppDesignSystem.paddingLarge)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppDesignSystem.paddingLarge)
            }
        }
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
                        if description.contains("已被使用") || nsError.code == 17007 { // Firebase Auth "email-already-in-use" code
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

// MARK: - Particle View (Placeholder for dynamic background)
struct ParticleView: View {
    var body: some View {
        // This could be a complex view for dynamic particles,
        // subtle gradients, or animated shapes that enhance the glass effect.
        // For now, it's just a clear view.
        LinearGradient(gradient: Gradient(colors: [Color.appPrimaryBackground.opacity(0.8), Color.appPrimaryBackground.opacity(0.9)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
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
