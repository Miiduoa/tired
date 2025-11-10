import Foundation
import FirebaseFirestore

protocol FriendsServiceProtocol {
    func friends(of userId: String) async -> [Friend]
    func requests(for userId: String) async -> [FriendRequest]
    func accept(requestId: String, for userId: String) async throws
    func decline(requestId: String, for userId: String) async throws
    func sendRequest(from: String, to: String) async throws
    func removeFriend(friendId: String, for userId: String) async throws
}

@MainActor
final class FriendsService: FriendsServiceProtocol {
    static let shared = FriendsService()
    private let db = Firestore.firestore()
    
    private var friendsCache: [String: [Friend]] = [:]
    private var requestsCache: [String: [FriendRequest]] = [:]
    
    private init() {}

    func friends(of userId: String) async -> [Friend] {
        do {
            // 從 Firestore 獲取好友列表
            let snapshot = try await db.collection("friends")
                .whereField("userId", isEqualTo: userId)
                .order(by: "since", descending: true)
                .getDocuments()
            
            var friends: [Friend] = []
            for doc in snapshot.documents {
                if let friendId = doc.data()["friendId"] as? String,
                   let since = (doc.data()["since"] as? Timestamp)?.dateValue() {
                    // 獲取好友的用戶資料
                    if let friendUser = try? await fetchUser(userId: friendId) {
                        let friend = Friend(
                            id: doc.documentID,
                            user: friendUser,
                            since: since
                        )
                        friends.append(friend)
                    }
                }
            }
            
            // 更新快取
            friendsCache[userId] = friends
            
            // 如果 Firestore 沒有數據，返回 demo 數據
            if friends.isEmpty {
                return await createDemoFriends()
            }
            
            return friends
        } catch {
            print("❌ 獲取好友列表失敗: \(error.localizedDescription)")
            // 返回快取或 demo 數據
            if let cached = friendsCache[userId], !cached.isEmpty {
                return cached
            }
            return await createDemoFriends()
        }
    }
    
    private func createDemoFriends() async -> [Friend] {
        return await MockDataProvider.shared.mockFriends()
    }

    func requests(for userId: String) async -> [FriendRequest] {
        do {
            // 從 Firestore 獲取好友請求
            let snapshot = try await db.collection("friend_requests")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var requests: [FriendRequest] = []
            for doc in snapshot.documents {
                if let fromUserId = doc.data()["fromUserId"] as? String,
                   let createdAt = (doc.data()["createdAt"] as? Timestamp)?.dateValue() {
                    // 獲取請求者的用戶資料
                    if let fromUser = try? await fetchUser(userId: fromUserId) {
                        let request = FriendRequest(
                            id: doc.documentID,
                            from: fromUser,
                            createdAt: createdAt
                        )
                        requests.append(request)
                    }
                }
            }
            
            // 更新快取
            requestsCache[userId] = requests
            
            // 如果 Firestore 沒有數據，返回 demo 數據
            if requests.isEmpty, userId == "demo" {
                let demoRequests = await MockDataProvider.shared.mockFriendRequests()
                requestsCache[userId] = demoRequests
                return demoRequests
            }
            
            return requests
        } catch {
            print("❌ 獲取好友請求失敗: \(error.localizedDescription)")
            // 返回快取
            return requestsCache[userId] ?? []
        }
    }

    func accept(requestId: String, for userId: String) async throws {
        do {
            // 獲取請求詳情
            let requestDoc = try await db.collection("friend_requests").document(requestId).getDocument()
            guard let fromUserId = requestDoc.data()?["fromUserId"] as? String else {
                throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "找不到請求"])
            }
            
            // 更新請求狀態
            try await db.collection("friend_requests").document(requestId).updateData([
                "status": "accepted",
                "acceptedAt": FieldValue.serverTimestamp()
            ])
            
            // 創建雙向好友關係
            let batch = db.batch()
            
            let friend1Ref = db.collection("friends").document()
            batch.setData([
                "userId": userId,
                "friendId": fromUserId,
                "since": FieldValue.serverTimestamp()
            ], forDocument: friend1Ref)
            
            let friend2Ref = db.collection("friends").document()
            batch.setData([
                "userId": fromUserId,
                "friendId": userId,
                "since": FieldValue.serverTimestamp()
            ], forDocument: friend2Ref)
            
            try await batch.commit()
            
            // 更新快取
            var reqs = requestsCache[userId] ?? []
            reqs.removeAll { $0.id == requestId }
            requestsCache[userId] = reqs
            
            // 刷新好友列表快取
            friendsCache.removeValue(forKey: userId)
            
        } catch {
            print("❌ 接受好友請求失敗: \(error.localizedDescription)")
            throw error
        }
    }

    func decline(requestId: String, for userId: String) async throws {
        do {
            // 更新請求狀態
            try await db.collection("friend_requests").document(requestId).updateData([
                "status": "declined",
                "declinedAt": FieldValue.serverTimestamp()
            ])
            
            // 更新快取
            var reqs = requestsCache[userId] ?? []
            reqs.removeAll { $0.id == requestId }
            requestsCache[userId] = reqs
            
        } catch {
            print("❌ 拒絕好友請求失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    func sendRequest(from fromUserId: String, to toUserId: String) async throws {
        do {
            // 檢查是否已經是好友
            let existingFriend = try await db.collection("friends")
                .whereField("userId", isEqualTo: fromUserId)
                .whereField("friendId", isEqualTo: toUserId)
                .getDocuments()
            
            if !existingFriend.documents.isEmpty {
                throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "已經是好友"])
            }
            
            // 檢查是否已經發送過請求
            let existingRequest = try await db.collection("friend_requests")
                .whereField("fromUserId", isEqualTo: fromUserId)
                .whereField("toUserId", isEqualTo: toUserId)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            
            if !existingRequest.documents.isEmpty {
                throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "已經發送過請求"])
            }
            
            // 創建新請求
            let requestRef = db.collection("friend_requests").document()
            try await requestRef.setData([
                "fromUserId": fromUserId,
                "toUserId": toUserId,
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ 好友請求已發送")
            var outgoing = requestsCache[toUserId] ?? []
            if let fromUser = try? await fetchUser(userId: fromUserId) {
                let request = FriendRequest(id: requestRef.documentID, from: fromUser, createdAt: Date())
                outgoing.insert(request, at: 0)
                requestsCache[toUserId] = outgoing
            }
            
        } catch {
            print("❌ 發送好友請求失敗: \(error.localizedDescription)")
            throw error
        }
    }

    func removeFriend(friendId: String, for userId: String) async throws {
        do {
            let query = try await db.collection("friends")
                .whereField("userId", isEqualTo: userId)
                .whereField("friendId", isEqualTo: friendId)
                .getDocuments()
            for doc in query.documents {
                try await doc.reference.delete()
            }
            let reverse = try await db.collection("friends")
                .whereField("userId", isEqualTo: friendId)
                .whereField("friendId", isEqualTo: userId)
                .getDocuments()
            for doc in reverse.documents {
                try await doc.reference.delete()
            }
            var list = friendsCache[userId] ?? []
            list.removeAll { $0.user.id == friendId || $0.id == friendId }
            friendsCache[userId] = list
        } catch {
            print("❌ 刪除好友失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchUser(userId: String) async throws -> FriendUser {
        // 從 Firestore 獲取用戶資料
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        let displayName = userDoc.data()?["displayName"] as? String ?? "用戶"
        let photoURL = userDoc.data()?["photoURL"] as? String
        
        return FriendUser(
            id: userId,
            displayName: displayName,
            photoURL: photoURL
        )
    }
}
