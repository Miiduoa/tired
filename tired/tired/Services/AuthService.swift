import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import Security
import UIKit

// MARK: - 認證服務

@MainActor
final class AuthService: NSObject, ObservableObject {
    struct AuthAlert: Identifiable {
        enum Kind {
            case error
            case success
            case info
        }
        
        let id = UUID()
        let kind: Kind
        let message: String
        
        var title: String {
            switch kind {
            case .error: return "錯誤"
            case .success: return "完成"
            case .info: return "提示"
            }
        }
    }
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var activeAlert: AuthAlert?
    
    private let firebase = FirebaseService.shared
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var pendingPhoneVerificationID: String?
    private var pendingPhoneNumber: String?
    private let preferencesStore = UserPreferencesStore()
    
    override init() {
        super.init()
        firebase.configureIfNeeded()
        observeAuthState()
    }
    
    deinit {
        if let handle = authHandle {
            firebase.removeAuthStateListener(handle)
        }
    }
    
    // MARK: - Auth State
    
    private func observeAuthState() {
        authHandle = firebase.addAuthStateListener { [weak self] user in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthStateChange(user: user)
            }
        }
    }
    
    private func handleAuthStateChange(user: FirebaseAuth.User?) {
        defer { isLoading = false }
        guard let user else {
            isAuthenticated = false
            currentUser = nil
            return
        }
        
        currentUser = User(firebaseUser: user, preferences: preferencesStore.loadPreferences(for: user.uid))
        isAuthenticated = true
    }
    
    func refreshCurrentUser() async {
        guard let firebaseUser = firebase.currentUser else { return }
        currentUser = User(firebaseUser: firebaseUser, preferences: preferencesStore.loadPreferences(for: firebaseUser.uid))
    }
    
    // MARK: - Apple 登入/註冊
    
    func signInWithApple() {
        guard !isLoading else { return }
        isLoading = true
        activeAlert = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func signUpWithApple() {
        signInWithApple()
    }
    
    // MARK: - Google 登入/註冊
    
    func signInWithGoogle(isSignUp: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        activeAlert = nil
        
        guard let presentingViewController = Self.rootViewController else {
            isLoading = false
            presentAlert(.error, message: "無法取得視窗控制器")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                    return
                }
                
                guard let result = result,
                      let idToken = result.user.idToken?.tokenString else {
                    self.isLoading = false
                    self.presentAlert(.error, message: "無法取得 Google 身分驗證資訊")
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
                
                do {
                    let _ = try await self.firebase.signIn(with: credential)
                    await self.refreshCurrentUser()
                    
                    self.isLoading = false
                    if isSignUp {
                        self.presentAlert(.success, message: "Google 註冊成功！歡迎使用 Tired！")
                    }
                } catch {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    func signUpWithGoogle() {
        signInWithGoogle(isSignUp: true)
    }
    
    // MARK: - 電子郵件登入 / 註冊
    
    func signInWithEmail(email: String, password: String) {
        guard validateEmailPassword(email: email, password: password) else { return }
        runAuthTask {
            try await self.firebase.signIn(email: email, password: password)
        }
    }
    
    func signUpWithEmail(email: String, password: String, displayName: String) {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            presentAlert(.error, message: "請輸入顯示名稱。")
            return
        }
        guard validateEmailPassword(email: email, password: password) else { return }
        
        runAuthTask(successMessage: "註冊成功！請前往信箱完成郵件驗證。") {
            try await self.firebase.createUser(email: email, password: password, displayName: displayName)
        }
    }
    
    private func validateEmailPassword(email: String, password: String) -> Bool {
        guard email.contains("@") else {
            presentAlert(.error, message: "請輸入有效的電子郵件地址。")
            return false
        }
        guard password.count >= 6 else {
            presentAlert(.error, message: "密碼至少需 6 碼。")
            return false
        }
        return true
    }
    
    private func runAuthTask(successMessage: String? = nil, operation: @escaping () async throws -> FirebaseAuth.User) {
        guard !isLoading else { return }
        isLoading = true
        activeAlert = nil
        
        Task {
            do {
                let firebaseUser = try await operation()
                currentUser = User(firebaseUser: firebaseUser, preferences: preferencesStore.loadPreferences(for: firebaseUser.uid))
                isAuthenticated = true
                
                await MainActor.run {
                    self.isLoading = false
                    if let successMessage {
                        self.presentAlert(.success, message: successMessage)
                    }
                }
            } catch {
                await MainActor.run {
            self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    // MARK: - 密碼重置
    
    func resetPassword(email: String) {
        guard email.contains("@") else {
            presentAlert(.error, message: "請輸入有效的電子郵件地址。")
            return
        }
        guard !isLoading else { return }
        
        isLoading = true
        activeAlert = nil
        
        Task {
            do {
                try await firebase.sendPasswordReset(email: email)
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.info, message: "重設密碼的連結已寄到 \(email)")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    // MARK: - 電子郵件驗證
    
    func sendEmailVerification() {
        guard let firebaseUser = firebase.currentUser else {
            presentAlert(.error, message: "請先登入後再驗證電子郵件。")
            return
        }
        guard !isLoading else { return }
        
        isLoading = true
        activeAlert = nil
        
        Task {
            do {
                try await firebaseUser.sendEmailVerification()
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.info, message: "驗證郵件已寄出，請至信箱確認。")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    func refreshEmailVerificationStatus() {
        Task {
            guard let firebaseUser = firebase.currentUser else {
                await MainActor.run {
                    self.presentAlert(.info, message: "尚未偵測到驗證完成，請確認郵件是否已點擊。")
                }
                return
            }
            
            try? await firebaseUser.reload()
            await refreshCurrentUser()
            
            await MainActor.run {
                if firebaseUser.isEmailVerified {
                    self.presentAlert(.success, message: "電子郵件驗證成功！")
            } else {
                    self.presentAlert(.info, message: "尚未偵測到驗證完成，請確認郵件是否已點擊。")
                }
            }
        }
    }
    
    // MARK: - 手機號碼驗證
    
    func startPhoneVerification(phoneNumber: String) {
        guard !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            presentAlert(.error, message: "請輸入手機號碼。")
            return
        }
        guard !isLoading else { return }
        
        isLoading = true
        activeAlert = nil
        
        Task {
            do {
                let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
                await MainActor.run {
                    self.pendingPhoneVerificationID = verificationID
                    self.pendingPhoneNumber = phoneNumber
                    self.isLoading = false
                    self.presentAlert(.info, message: "驗證簡訊已發送到 \(phoneNumber)")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    func verifyPhone(with code: String) {
        guard let verificationID = pendingPhoneVerificationID,
              pendingPhoneNumber != nil else {
            presentAlert(.error, message: "請先發送驗證碼。")
            return
        }
        guard code.count >= 6 else {
            presentAlert(.error, message: "請輸入有效的驗證碼。")
            return
        }
        guard !isLoading else { return }
        
        isLoading = true
        activeAlert = nil
        
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        
        Task {
            do {
                guard let firebaseUser = firebase.currentUser else {
                    throw NSError(domain: "AuthService", code: 999, userInfo: [NSLocalizedDescriptionKey: "請先登入"])
                }
                
                try await firebaseUser.link(with: credential)
                await refreshCurrentUser()
                
                await MainActor.run {
                    self.isLoading = false
                    self.pendingPhoneVerificationID = nil
                    self.pendingPhoneNumber = nil
                    self.presentAlert(.success, message: "手機號碼驗證成功！")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    // MARK: - 登出
    
    func signOut() {
        guard !isLoading else { return }
        isLoading = true
        
        Task { @MainActor in
            do {
                try firebase.signOut()
                isAuthenticated = false
                currentUser = nil
                isLoading = false
                // 清理狀態
                currentNonce = nil
                pendingPhoneVerificationID = nil
                pendingPhoneNumber = nil
                activeAlert = nil
            } catch {
                isLoading = false
                presentAlert(.error, message: message(for: error))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func presentAlert(_ kind: AuthAlert.Kind, message: String) {
        activeAlert = AuthAlert(kind: kind, message: message)
    }
    
    private func message(for error: Error) -> String {
        ErrorHandler.localizedMessage(for: error)
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with code \(status)")
            }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private static var rootViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return scene.windows.first { $0.isKeyWindow }?.rootViewController
    }
}

// MARK: - Apple Sign-In Delegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            isLoading = false
            presentAlert(.error, message: "Apple 登入流程發生錯誤，請再試一次。")
            return
        }
        guard let nonce = currentNonce else {
            isLoading = false
            presentAlert(.error, message: "登入流程失效，請重新嘗試。")
            return
        }
        guard let tokenData = appleIDCredential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            isLoading = false
            presentAlert(.error, message: "無法取得 Apple 身分驗證資訊。")
            return
        }
        
        Task {
            do {
                let credential = OAuthProvider.appleCredential(
                    withIDToken: tokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                let firebaseUser = try await firebase.signIn(with: credential)
                
                if let name = appleIDCredential.fullName,
                   let displayName = [name.givenName, name.familyName].compactMap({ $0 }).joined().nilIfEmpty {
                    let changeRequest = firebaseUser.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChangesAsync()
                }
                
                await refreshCurrentUser()
                
                await MainActor.run {
                    self.isLoading = false
            if appleIDCredential.fullName != nil {
                        self.presentAlert(.success, message: "Apple 註冊成功！歡迎使用 Tired！")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.presentAlert(.error, message: self.message(for: error))
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        presentAlert(.error, message: message(for: error))
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Firebase 轉換輔助

extension User {
    init(firebaseUser: FirebaseAuth.User, preferences: UserPreferences = UserPreferences()) {
        self.init(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName ?? "",
            photoURL: firebaseUser.photoURL?.absoluteString,
            provider: firebaseUser.providerData.first?.providerID ?? "unknown",
            phoneNumber: firebaseUser.phoneNumber,
            isEmailVerified: firebaseUser.isEmailVerified,
            isPhoneVerified: firebaseUser.phoneNumber != nil,
            createdAt: firebaseUser.metadata.creationDate ?? Date(),
            lastLoginAt: firebaseUser.metadata.lastSignInDate ?? Date(),
            preferences: preferences
        )
    }
}

// MARK: - 補助型別 / 擴充

private final class UserPreferencesStore {
    private let defaults = UserDefaults.standard
    
    func loadPreferences(for userId: String) -> UserPreferences {
        guard let data = defaults.data(forKey: key(for: userId)),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return preferences
    }
    
    func save(_ preferences: UserPreferences, for userId: String) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key(for: userId))
    }
    
    func savePhoneNumber(_ phone: String, for userId: String) {
        let preferences = loadPreferences(for: userId)
        // 預留擴充偏好設定的儲存位置
        save(preferences, for: userId)
    }
    
    private func key(for userId: String) -> String {
        "UserPreferences.\(userId)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension UserProfileChangeRequest {
    func commitChangesAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}
