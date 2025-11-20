import Foundation
import FirebaseFirestore
import Combine

/// 用戶服務
class UserService: ObservableObject {
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
}
