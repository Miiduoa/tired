import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(isSignUp ? "註冊資訊" : "登入資訊")) {
                    TextField("電子郵件", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("密碼", text: $password)
                    if isSignUp {
                        TextField("顯示名稱", text: $displayName)
                    }
                }
                
                Section {
                    if authService.isLoading {
                        ProgressView("處理中...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Button(isSignUp ? "建立帳號" : "登入") {
                            if isSignUp {
                                authService.signUpWithEmail(email: email, password: password, displayName: displayName.isEmpty ? email : displayName)
                            } else {
                                authService.signInWithEmail(email: email, password: password)
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty)
                        
                        Button(isSignUp ? "已有帳號？改為登入" : "沒有帳號？建立新帳號") {
                            withAnimation { isSignUp.toggle() }
                        }
                    }
                }
                
                Section(header: Text("第三方登入")) {
                    Button("使用 Apple 登入") { authService.signInWithApple() }
                        .disabled(authService.isLoading)
                    Button("使用 Google 登入") { authService.signInWithGoogle() }
                        .disabled(authService.isLoading)
                }
                
                Section(header: Text("帳號安全")) {
                    Button("重設密碼") { authService.resetPassword(email: email) }
                        .disabled(authService.isLoading || !email.contains("@"))
                    Button("寄送驗證郵件") { authService.sendEmailVerification() }
                        .disabled(authService.currentUser == nil || authService.isLoading)
                    Button("我已完成郵件驗證") { authService.refreshEmailVerificationStatus() }
                        .disabled(authService.currentUser == nil || authService.isLoading)
                }
            }
            .navigationTitle("登入 tired")
        }
        .alert(item: $authService.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("確定")) {
                authService.activeAlert = nil
            })
        }
    }
}
