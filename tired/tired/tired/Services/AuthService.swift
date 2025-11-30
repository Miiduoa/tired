import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import GoogleSignIn
import UIKit

/// 认证服务
class AuthService: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private let db = FirebaseManager.shared.db

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            if let uid = user?.uid {
                self?.fetchUserProfile(uid: uid)
            } else {
                self?.userProfile = nil
                self?.isLoading = false
            }
        }
    }

    // MARK: - User Profile

    func fetchUserProfile(uid: String) {
        db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }

            if let error = error {
                print("❌ Error fetching user profile: \(error.localizedDescription)")
                // 如果是文檔不存在，不視為錯誤（可能是剛註冊）
                if (error as NSError).code != 5 { // 5 = not found
                    return
                }
            }

            guard let snapshot = snapshot, snapshot.exists else {
                print("⚠️ User profile not found for uid: \(uid)")
                return
            }

            do {
                var profile = try snapshot.data(as: UserProfile.self)
                profile.id = uid
                DispatchQueue.main.async {
                    self.userProfile = profile
                }
            } catch {
                print("❌ Error decoding user profile: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sign In / Sign Up

    func signIn(email: String, password: String) async throws {
        // 確保 Firebase 已初始化
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase 未正確初始化，請檢查 GoogleService-Info.plist 配置"])
        }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            // 登入成功後，authStateListener 會自動觸發 fetchUserProfile
        } catch {
            // 提供更友好的錯誤訊息
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain" {
                switch nsError.code {
                case 17008: // Invalid email
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "請輸入有效的電子郵件地址"])
                case 17009: // Wrong password
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "密碼錯誤"])
                case 17011: // User not found
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "找不到此用戶，請先註冊"])
                case 17020: // Network error
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "網路連線錯誤，請檢查網路設定"])
                case 17025: // Invalid credential / malformed
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Firebase 配置錯誤。請確認 GoogleService-Info.plist 已正確添加到專案，且 Bundle ID 與 Firebase 專案中的一致"])
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        // 確保 Firebase 已初始化
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase 未正確初始化，請檢查 GoogleService-Info.plist 配置"])
        }

        do {
            // 創建 Firebase Auth 用戶
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // 創建用戶 profile
            let profile = UserProfile(
                id: uid,
                name: name,
                email: email,
                timezone: TimeZone.current.identifier,
                weeklyCapacityMinutes: 720  // 默认12小时/周
            )

            // 保存 profile 到 Firestore
            try await createUserProfile(profile)
            
            // 優化：樂觀更新 (Optimistic Update)
            // 不等待 Firestore 寫入完成後的讀取，直接使用剛創建的資料更新本地狀態
            // 這樣可以避免網路延遲導致的資料不同步或需要人工等待 (sleep)
            await MainActor.run {
                self.userProfile = profile
                self.isLoading = false
            }
            
            // 背景觸發一次真實的 Fetch 以確保一致性
            _Concurrency.Task {
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1秒後檢查
                self.fetchUserProfile(uid: uid)
            }
        } catch {
            // 提供更友好的錯誤訊息
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain" {
                switch nsError.code {
                case 17007: // Email already in use
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "此電子郵件已被使用。請切換到「登入」模式，或使用其他郵件地址註冊"])
                case 17008: // Invalid email
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "請輸入有效的電子郵件地址"])
                case 17026: // Weak password
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "密碼強度不足，請使用至少6個字符"])
                case 17020: // Network error
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "網路連線錯誤，請檢查網路設定"])
                case 17025: // Invalid credential / malformed
                    throw NSError(domain: "AuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Firebase 配置錯誤。請確認 GoogleService-Info.plist 已正確添加到專案，且 Bundle ID 與 Firebase 專案中的一致"])
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        // 確保 Firebase 已初始化
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase 未正確初始化，請檢查 GoogleService-Info.plist 配置"])
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法獲取 Google Client ID，請檢查 GoogleService-Info.plist"])
        }

        // 創建 Google Sign-In 配置
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 執行 Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法獲取 Google ID Token"])
        }

        // 使用 Google ID Token 登入 Firebase
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let uid = authResult.user.uid

        // 檢查用戶 profile 是否存在，如果不存在則創建
        let userDoc = try? await db.collection("users").document(uid).getDocument()

        if userDoc?.exists == false {
            // 創建新用戶 profile
            let profile = UserProfile(
                id: uid,
                name: authResult.user.displayName ?? "Google 用戶",
                email: authResult.user.email ?? "",
                avatarUrl: authResult.user.photoURL?.absoluteString,
                timezone: TimeZone.current.identifier,
                weeklyCapacityMinutes: 720
            )

            try await createUserProfile(profile)

            // 優化：樂觀更新本地狀態
            await MainActor.run {
                self.userProfile = profile
            }
        }
        
        // 手動觸發獲取 profile (背景執行)
        _Concurrency.Task {
            // 如果剛創建，給一點時間寫入；如果是舊用戶，直接讀取
            if userDoc?.exists == false {
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            }
            self.fetchUserProfile(uid: uid)
        }
    }

    func signOut() throws {
        // 登出 Google Sign-In
        GIDSignIn.sharedInstance.signOut()
        // 登出 Firebase
        try Auth.auth().signOut()
    }

    // MARK: - Profile Management

    private func createUserProfile(_ profile: UserProfile) async throws {
        guard let uid = profile.id else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is missing"])
        }

        try db.collection("users").document(uid).setData(from: profile)
    }

    func updateUserProfile(_ updates: [String: Any]) async throws {
        guard let uid = currentUser?.uid else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        var updatesWithTimestamp = updates
        updatesWithTimestamp["updatedAt"] = Timestamp(date: Date())

        try await db.collection("users").document(uid).updateData(updatesWithTimestamp)
    }
}
