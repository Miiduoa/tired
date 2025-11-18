import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

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
            defer { self?.isLoading = false }

            if let error = error {
                print("❌ Error fetching user profile: \(error)")
                return
            }

            guard let data = snapshot?.data() else { return }

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                var profile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                profile.id = uid
                self?.userProfile = profile
            } catch {
                print("❌ Error decoding user profile: \(error)")
            }
        }
    }

    // MARK: - Sign In / Sign Up

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String, name: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        // Create user profile
        let profile = UserProfile(
            id: uid,
            name: name,
            email: email,
            timezone: TimeZone.current.identifier,
            weeklyCapacityMinutes: 720  // 默认12小时/周
        )

        try await createUserProfile(profile)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Profile Management

    private func createUserProfile(_ profile: UserProfile) async throws {
        guard let uid = profile.id else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is missing"])
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        try await db.collection("users").document(uid).setData(dict)
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
