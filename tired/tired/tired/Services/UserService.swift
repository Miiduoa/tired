import Foundation
import FirebaseFirestore
import Combine

/// 用戶服務
class UserService: ObservableObject {
    // 全域共用實例，便於跨模組共用快取與呼叫
    static let shared = UserService()

    private let db = FirebaseManager.shared.db

    // 緩存用戶資料，避免重複查詢
    private var userProfileCache: [String: UserProfile] = [:]

    // MARK: - Fetch User Profile

    /// 獲取單個用戶資料
    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        // 先檢查緩存
        if let cachedProfile = userProfileCache[userId] {
            return cachedProfile
        }

        // 從 Firestore 獲取
        let document = try await db.collection("users").document(userId).getDocument()

        guard document.exists else {
            return nil
        }

        var profile = try document.data(as: UserProfile.self)
        profile.id = userId

        // 緩存結果
        userProfileCache[userId] = profile

        return profile
    }

    /// 批量獲取用戶資料
    func fetchUserProfiles(userIds: [String]) async throws -> [String: UserProfile] {
        var profiles: [String: UserProfile] = [:]

        // 過濾掉已緩存的
        let uncachedIds = userIds.filter { userProfileCache[$0] == nil }

        // 返回緩存的數據
        for userId in userIds {
            if let cached = userProfileCache[userId] {
                profiles[userId] = cached
            }
        }

        // 如果沒有需要獲取的，直接返回
        if uncachedIds.isEmpty {
            return profiles
        }

        // Firestore 限制 in 查詢最多 30 個元素，需要分批
        let batchSize = 30
        for i in stride(from: 0, to: uncachedIds.count, by: batchSize) {
            let end = min(i + batchSize, uncachedIds.count)
            let batch = Array(uncachedIds[i..<end])

            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()

            for doc in snapshot.documents {
                if var profile = try? doc.data(as: UserProfile.self) {
                    profile.id = doc.documentID
                    profiles[doc.documentID] = profile
                    userProfileCache[doc.documentID] = profile
                }
            }
        }

        return profiles
    }

    /// 清除緩存
    func clearCache() {
        userProfileCache.removeAll()
    }

    /// 清除特定用戶的緩存
    func clearCache(for userId: String) {
        userProfileCache.removeValue(forKey: userId)
    }

    // MARK: - Update Settings

    /// 更新時間管理設定
    func updateTimeManagementSettings(userId: String, weeklyCapacityMinutes: Int, dailyCapacityMinutes: Int) async throws {
        let updates: [String: Any] = [
            "weeklyCapacityMinutes": weeklyCapacityMinutes,
            "dailyCapacityMinutes": dailyCapacityMinutes,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId).updateData(updates)
        clearCache(for: userId)
    }

    /// 更新通知設定
    func updateNotificationSettings(
        userId: String,
        notificationsEnabled: Bool,
        taskReminders: Bool,
        eventReminders: Bool,
        organizationUpdates: Bool
    ) async throws {
        let updates: [String: Any] = [
            "notificationsEnabled": notificationsEnabled,
            "taskReminders": taskReminders,
            "eventReminders": eventReminders,
            "organizationUpdates": organizationUpdates,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId).updateData(updates)
        clearCache(for: userId)
    }

    /// 更新外觀設定
    func updateAppearanceSettings(userId: String, theme: String) async throws {
        let updates: [String: Any] = [
            "theme": theme,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId).updateData(updates)
        clearCache(for: userId)
    }

    /// 更新用戶資料
    func updateUserProfile(userId: String, name: String, avatarUrl: String?) async throws {
        var updates: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let avatarUrl = avatarUrl {
            updates["avatarUrl"] = avatarUrl
        }

        try await db.collection("users").document(userId).updateData(updates)
        clearCache(for: userId)
    }

    /// 更新 FCM Token
    func updateFCMToken(userId: String, token: String) async throws {
        let updates: [String: Any] = [
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId).updateData(updates)
        
        // 不需要清除緩存，因為 token 通常在背景更新，不影響當前顯示的 UserProfile
    }
    
    /// 根據使用者名稱查詢使用者ID (在特定組織內)
    /// - Warning: This is an inefficient operation as it requires fetching all members and then their profiles.
    /// A more scalable solution would involve a dedicated search index (like Algolia) for users.
    func fetchUserIds(forUsernames usernames: [String], in orgId: String) async -> [String] {
        let lowercasedUsernames = usernames.map { $0.lowercased() }
        
        do {
            // 1. Get all memberships for the organization
            let memberSnapshot = try await db.collection("memberships").whereField("organizationId", isEqualTo: orgId).getDocuments()
            let memberUserIds = memberSnapshot.documents.compactMap { $0.data()["userId"] as? String }
            
            guard !memberUserIds.isEmpty else { return [] }
            
            // 2. Fetch all user profiles for those members
            let profiles = try await fetchUserProfiles(userIds: memberUserIds)
            
            // 3. Filter the profiles by the provided usernames and return the IDs
            let foundIds = profiles.values.filter { profile in
                lowercasedUsernames.contains(profile.name.lowercased())
            }.compactMap { $0.id }
            
            return foundIds
        } catch {
            print("❌ Error fetching user IDs for usernames: \(error)")
            return []
        }
    }

    /// 依電子郵件精確查詢用戶
    /// - Parameter email: 要查詢的電子郵件（不分大小寫）
    /// - Returns: 匹配的 UserProfile；若不存在則為 nil
    func fetchUserProfile(byEmail email: String) async throws -> UserProfile? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = trimmed.lowercased()
        guard !normalizedEmail.isEmpty else { return nil }

        // 嘗試從快取取得
        if let cached = userProfileCache.values.first(where: { $0.email.lowercased() == normalizedEmail }) {
            return cached
        }

        // 順序：先用小寫 Email 查詢，若未命中且原始有大小寫差異，再嘗試原始字串
        let candidates = Array(Set([normalizedEmail, trimmed]))
        for candidate in candidates {
            let snapshot = try await db.collection("users")
                .whereField("email", isEqualTo: candidate)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                var profile = try doc.data(as: UserProfile.self)
                profile.id = doc.documentID
                userProfileCache[doc.documentID] = profile
                return profile
            }
        }

        return nil
    }
    
    // MARK: - Follow/Unfollow
    
    /// 追蹤用戶
    func followUser(followerId: String, followingId: String) async throws {
        guard followerId != followingId else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "不能追蹤自己"])
        }
        
        let followData: [String: Any] = [
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // 使用複合鍵確保唯一性
        let followDocId = "\(followerId)_\(followingId)"
        try await db.collection("follows").document(followDocId).setData(followData)
    }
    
    /// 取消追蹤用戶
    func unfollowUser(followerId: String, followingId: String) async throws {
        let followDocId = "\(followerId)_\(followingId)"
        try await db.collection("follows").document(followDocId).delete()
    }
    
    /// 檢查是否正在追蹤某個用戶
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let followDocId = "\(followerId)_\(followingId)"
        let doc = try await db.collection("follows").document(followDocId).getDocument()
        return doc.exists
    }
    
    /// 獲取追蹤者列表
    func getFollowers(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { $0.data()["followerId"] as? String }
    }
    
    /// 獲取正在追蹤的用戶列表
    func getFollowing(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { $0.data()["followingId"] as? String }
    }
}
