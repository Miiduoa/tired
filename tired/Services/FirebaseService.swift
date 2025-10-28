import Foundation
import FirebaseCore
import FirebaseAuth

/// 集中管理 Firebase 初始設定與 Auth 相關操作。
final class FirebaseService {
    static let shared = FirebaseService()
    
    private var isConfigured = false
    
    private init() {}
    
    func configureIfNeeded() {
        guard !isConfigured else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = true
    }
    
    var currentUser: FirebaseAuth.User? { Auth.auth().currentUser }
    
    func addAuthStateListener(_ handler: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }
    
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle?) {
        guard let handle else { return }
        Auth.auth().removeStateDidChangeListener(handle)
    }
    
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let user = result?.user { continuation.resume(returning: user) }
                else { continuation.resume(throwing: AuthErrorCode.internalError.makeError()) }
            }
        }
    }
    
    func createUser(email: String, password: String, displayName: String?) async throws -> FirebaseAuth.User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                if let error { continuation.resume(throwing: error); return }
                guard let user = result?.user else {
                    continuation.resume(throwing: AuthErrorCode.internalError.makeError())
                    return
                }
                if let displayName, !displayName.isEmpty {
                    let change = user.createProfileChangeRequest()
                    change.displayName = displayName
                    change.commitChanges { profileError in
                        if let profileError {
                            continuation.resume(throwing: profileError)
                        } else {
                            self?.reloadUser(user) { reloadError in
                                if let reloadError {
                                    continuation.resume(throwing: reloadError)
                                } else {
                                    continuation.resume(returning: user)
                                }
                            }
                        }
                    }
                } else {
                    continuation.resume(returning: user)
                }
            }
        }
    }
    
    func sendPasswordReset(email: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func signIn(with credential: AuthCredential) async throws -> FirebaseAuth.User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let user = result?.user { continuation.resume(returning: user) }
                else { continuation.resume(throwing: AuthErrorCode.internalError.makeError()) }
            }
        }
    }
    
    func sendEmailVerification(to user: FirebaseAuth.User) async throws {
        try await withCheckedThrowingContinuation { continuation in
            user.sendEmailVerification { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
    
    func reloadCurrentUser() async throws -> FirebaseAuth.User {
        guard let user = Auth.auth().currentUser else {
            throw AuthErrorCode.noCurrentUser.makeError()
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.reload { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: Auth.auth().currentUser ?? user) }
            }
        }
    }
    
    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                if let error { continuation.resume(throwing: error) }
                else if let verificationID { continuation.resume(returning: verificationID) }
                else { continuation.resume(throwing: AuthErrorCode.internalError.makeError()) }
            }
        }
    }
    
    func linkPhoneNumber(credential: PhoneAuthCredential) async throws -> FirebaseAuth.User {
        guard let user = Auth.auth().currentUser else {
            throw AuthErrorCode.noCurrentUser.makeError()
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.link(with: credential) { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let user = result?.user { continuation.resume(returning: user) }
                else { continuation.resume(throwing: AuthErrorCode.internalError.makeError()) }
            }
        }
    }
    
    func reloadUser(_ user: FirebaseAuth.User, completion: @escaping (Error?) -> Void) {
        user.reload(completion: completion)
    }
}

private extension AuthErrorCode {
    func makeError(userInfo: [String: Any] = [:]) -> NSError {
        NSError(domain: AuthErrorDomain, code: rawValue, userInfo: userInfo)
    }
}
