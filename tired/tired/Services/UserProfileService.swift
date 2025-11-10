import Foundation
import FirebaseFirestore
import UIKit

/// 用戶資料管理服務
@MainActor
final class UserProfileService {
    static let shared = UserProfileService()
    
    private let db = Firestore.firestore()
    private let fileUploadService = FileUploadService.shared
    private var profileCache: [String: UserProfile] = [:]
    
    private init() {}
    
    // MARK: - Profile Management
    
    /// 獲取用戶資料
    func fetchProfile(userId: String) async throws -> UserProfile {
        // 檢查快取
        if let cached = profileCache[userId] {
            return cached
        }
        
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            
            guard let data = doc.data() else {
                // 如果不存在，創建默認資料
                return try await createDefaultProfile(userId: userId)
            }
            
            let profile = try parseProfile(from: data, userId: userId)
            
            // 更新快取
            profileCache[userId] = profile
            
            return profile
        } catch {
            print("❌ 獲取用戶資料失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 更新用戶資料
    func updateProfile(userId: String, updates: ProfileUpdates) async throws {
        var updateData: [String: Any] = [:]
        
        if let displayName = updates.displayName {
            updateData["displayName"] = displayName
        }
        
        if let bio = updates.bio {
            updateData["bio"] = bio
        }
        
        if let location = updates.location {
            updateData["location"] = location
        }
        
        if let interests = updates.interests {
            updateData["interests"] = interests
        }
        
        if let visibility = updates.visibility {
            updateData["visibility"] = visibility.rawValue
        }
        
        updateData["updatedAt"] = FieldValue.serverTimestamp()
        
        do {
            try await db.collection("users").document(userId).updateData(updateData)
            
            // 清除快取
            profileCache.removeValue(forKey: userId)
            
            print("✅ 用戶資料已更新")
        } catch {
            print("❌ 更新用戶資料失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 上傳頭像
    func uploadAvatar(userId: String, image: UIImage) async throws -> String {
        do {
            // 上傳圖片
            let avatarURL = try await fileUploadService.uploadImage(
                image,
                category: .avatar,
                compress: true,
                quality: 0.9,
                maxDimension: 512
            )
            
            // 更新資料
            try await db.collection("users").document(userId).updateData([
                "photoURL": avatarURL,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 清除快取
            profileCache.removeValue(forKey: userId)
            
            print("✅ 頭像已上傳: \(avatarURL)")
            return avatarURL
        } catch {
            print("❌ 上傳頭像失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 上傳封面照片
    func uploadCoverPhoto(userId: String, image: UIImage) async throws -> String {
        do {
            // 上傳圖片
            let coverURL = try await fileUploadService.uploadImage(
                image,
                category: .image,
                compress: true,
                quality: 0.85,
                maxDimension: 1920
            )
            
            // 更新資料
            try await db.collection("users").document(userId).updateData([
                "coverPhotoURL": coverURL,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 清除快取
            profileCache.removeValue(forKey: userId)
            
            print("✅ 封面照片已上傳: \(coverURL)")
            return coverURL
        } catch {
            print("❌ 上傳封面照片失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Privacy Settings
    
    /// 更新可見度設置
    func updateVisibility(userId: String, visibility: ProfileVisibility) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "visibility": visibility.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 清除快取
            profileCache.removeValue(forKey: userId)
            
            print("✅ 可見度設置已更新")
        } catch {
            print("❌ 更新可見度失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 更新字段可見度
    func updateFieldVisibility(
        userId: String,
        field: ProfileField,
        visibility: FieldVisibility
    ) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "fieldVisibility.\(field.rawValue)": visibility.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // 清除快取
            profileCache.removeValue(forKey: userId)
            
            print("✅ 字段可見度已更新")
        } catch {
            print("❌ 更新字段可見度失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Batch Profile Fetch
    
    /// 批量獲取用戶資料
    func fetchProfiles(userIds: [String]) async throws -> [String: UserProfile] {
        var profiles: [String: UserProfile] = [:]
        
        // 先檢查快取
        for userId in userIds {
            if let cached = profileCache[userId] {
                profiles[userId] = cached
            }
        }
        
        // 獲取未快取的資料
        let uncachedIds = userIds.filter { profiles[$0] == nil }
        
        if !uncachedIds.isEmpty {
            // Firestore 的 in 查詢最多支持 10 個 ID
            let chunks = uncachedIds.chunked(into: 10)
            
            for chunk in chunks {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let data = doc.data() as? [String: Any],
                       let profile = try? parseProfile(from: data, userId: doc.documentID) {
                        profiles[doc.documentID] = profile
                        profileCache[doc.documentID] = profile
                    }
                }
            }
        }
        
        return profiles
    }
    
    // MARK: - Helpers
    
    private func parseProfile(from data: [String: Any], userId: String) throws -> UserProfile {
        let displayName = data["displayName"] as? String ?? "用戶"
        let email = data["email"] as? String
        let bio = data["bio"] as? String
        let photoURL = data["photoURL"] as? String
        let coverPhotoURL = data["coverPhotoURL"] as? String
        let location = data["location"] as? String
        let interests = data["interests"] as? [String] ?? []
        let visibilityString = data["visibility"] as? String ?? "public"
        let visibility = ProfileVisibility(rawValue: visibilityString) ?? .public
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return UserProfile(
            id: userId,
            displayName: displayName,
            email: email,
            bio: bio,
            photoURL: photoURL,
            coverPhotoURL: coverPhotoURL,
            location: location,
            interests: interests,
            visibility: visibility,
            createdAt: createdAt
        )
    }
    
    private func createDefaultProfile(userId: String) async throws -> UserProfile {
        let profile = UserProfile(
            id: userId,
            displayName: "新用戶",
            email: nil,
            bio: nil,
            photoURL: nil,
            coverPhotoURL: nil,
            location: nil,
            interests: [],
            visibility: .public,
            createdAt: Date()
        )
        
        // 保存到 Firestore
        let profileData: [String: Any] = [
            "displayName": profile.displayName,
            "visibility": profile.visibility.rawValue,
            "interests": profile.interests,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(profileData, merge: true)
        
        // 更新快取
        profileCache[userId] = profile
        
        return profile
    }
}

// MARK: - Models

struct UserProfile: Identifiable, Codable {
    let id: String
    let displayName: String
    let email: String?
    let bio: String?
    let photoURL: String?
    let coverPhotoURL: String?
    let location: String?
    let interests: [String]
    let visibility: ProfileVisibility
    let createdAt: Date
}

struct ProfileUpdates {
    var displayName: String?
    var bio: String?
    var location: String?
    var interests: [String]?
    var visibility: ProfileVisibility?
}

enum ProfileVisibility: String, Codable {
    case `public` = "public"
    case friends = "friends"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .public: return "公開"
        case .friends: return "僅好友"
        case .private: return "私密"
        }
    }
}

enum ProfileField: String {
    case email = "email"
    case bio = "bio"
    case location = "location"
    case interests = "interests"
}

enum FieldVisibility: String, Codable {
    case everyone = "everyone"
    case friends = "friends"
    case nobody = "nobody"
    
    var displayName: String {
        switch self {
        case .everyone: return "所有人"
        case .friends: return "僅好友"
        case .nobody: return "僅自己"
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

