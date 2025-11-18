import SwiftUI
import UIKit

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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 60)

                    // Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Tired")
                            .font(.system(size: 36, weight: .bold))

                        Text("多身份任务管理系统")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)

                    // Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("姓名", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }

                        TextField("邮箱", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
#endif

                        SecureField("密码", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isSignUp ? .newPassword : .password)

                        if let error = errorMessage {
                            VStack(spacing: 8) {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)

                                // 如果是「已被使用」錯誤，顯示切換提示
                                if error.contains("已被使用") {
                                    Button {
                                        withAnimation {
                                            isSignUp = false
                                            errorMessage = nil
                                        }
                                    } label: {
                                        Text("切換到登入模式")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Login/SignUp Button
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "注册" : "登入")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !isFormValid)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("或")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)

                        // Google Sign In Button
                        Button(action: handleGoogleSignIn) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .medium))
                                Text("使用 Google 登入")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)

                        // Toggle Sign Up / Login
                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            Text(isSignUp ? "已有账号？登入" : "没有账号？注册")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
#if os(iOS)
            .navigationBarHidden(true)
#endif
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
                // 成功時，AuthService 的狀態監聽器會自動更新 UI
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 顯示友好的錯誤訊息
                    let nsError = error as NSError
                    if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        errorMessage = description

                        // 如果是「電子郵件已被使用」錯誤，自動切換到登入模式
                        if description.contains("已被使用") || nsError.code == 17007 {
                            withAnimation {
                                isSignUp = false
                            }
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
                // 成功時，AuthService 的狀態監聽器會自動更新 UI
                await MainActor.run {
                    isLoading = false
                }
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
