import Foundation
import FirebaseFirestore

final class FriendsServiceFirestore: FriendsServiceProtocol, FriendsRealtimeListening {
    private let db = Firestore.firestore()

    func friends(of userId: String) async -> [Friend] {
        do {
            let snap = try await db.collection("users").document(userId).collection("friends")
                .order(by: "since", descending: true)
                .limit(to: 100)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard let displayName = data["displayName"] as? String,
                      let since = (data["since"] as? Timestamp)?.dateValue() else { return nil }
                let uid = data["uid"] as? String ?? doc.documentID
                let user = FriendUser(id: uid, displayName: displayName, photoURL: data["photoURL"] as? String)
                return Friend(id: doc.documentID, user: user, since: since)
            }
        } catch {
            return await FriendsService.shared.friends(of: userId)
        }
    }

    func requests(for userId: String) async -> [FriendRequest] {
        do {
            let snap = try await db.collection("users").document(userId).collection("friend_requests")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard let displayName = data["fromDisplayName"] as? String,
                      let created = (data["createdAt"] as? Timestamp)?.dateValue(),
                      let fromId = data["fromUid"] as? String else { return nil }
                let from = FriendUser(id: fromId, displayName: displayName, photoURL: data["fromPhotoURL"] as? String)
                return FriendRequest(id: doc.documentID, from: from, createdAt: created)
            }
        } catch {
            return await FriendsService.shared.requests(for: userId)
        }
    }

    func accept(requestId: String, for userId: String) async throws {
        let reqRef = db.collection("users").document(userId).collection("friend_requests").document(requestId)
        guard let data = try? await reqRef.getDocument().data(),
              let fromUid = data["fromUid"] as? String,
              let fromDisplay = data["fromDisplayName"] as? String else { return }
        let batch = db.batch()
        // add to friends (both sides)
        let now = Timestamp(date: Date())
        let myFriendRef = db.collection("users").document(userId).collection("friends").document(fromUid)
        batch.setData(["uid": fromUid, "displayName": fromDisplay, "since": now], forDocument: myFriendRef)
        let theirFriendRef = db.collection("users").document(fromUid).collection("friends").document(userId)
        batch.setData(["uid": userId, "displayName": "", "since": now], forDocument: theirFriendRef)
        // delete request
        batch.deleteDocument(reqRef)
        try await batch.commit()
    }

    func decline(requestId: String, for userId: String) async throws {
        let reqRef = db.collection("users").document(userId).collection("friend_requests").document(requestId)
        try? await reqRef.delete()
    }

    func sendRequest(from fromUserId: String, to toUserId: String) async throws {
        let trimmed = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "FriendsService", code: -2, userInfo: [NSLocalizedDescriptionKey: "請輸入好友 ID"])
        }
        // Prevent duplicate requests
        let existing = try await db.collection("users").document(trimmed)
            .collection("friend_requests")
            .whereField("fromUid", isEqualTo: fromUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        if !existing.documents.isEmpty {
            throw NSError(domain: "FriendsService", code: -3, userInfo: [NSLocalizedDescriptionKey: "已送出邀請，請等待回覆"])
        }

        // Create pending request under recipient
        let requestRef = db.collection("users").document(trimmed).collection("friend_requests").document(fromUserId)
        let now = Timestamp(date: Date())
        try await requestRef.setData([
            "fromUid": fromUserId,
            "fromDisplayName": "", // display name可於後端補
            "createdAt": now,
            "status": "pending"
        ], merge: true)
    }

    func removeFriend(friendId: String, for userId: String) async throws {
        let batch = db.batch()
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        batch.deleteDocument(myRef)
        let theirRef = db.collection("users").document(friendId).collection("friends").document(userId)
        batch.deleteDocument(theirRef)
        try await batch.commit()
    }

    @discardableResult
    func listenFriends(of userId: String, onChange: @escaping ([Friend]) -> Void) -> CancelableToken? {
        let query = db.collection("users").document(userId).collection("friends").order(by: "since", descending: true)
        let reg = query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let items: [Friend] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let displayName = data["displayName"] as? String,
                      let since = (data["since"] as? Timestamp)?.dateValue() else { return nil }
                let uid = data["uid"] as? String ?? doc.documentID
                let user = FriendUser(id: uid, displayName: displayName, photoURL: data["photoURL"] as? String)
                return Friend(id: doc.documentID, user: user, since: since)
            }
            onChange(items)
        }
        return FirebaseListenerToken(inner: reg)
    }

    @discardableResult
    func listenRequests(for userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> CancelableToken? {
        let query = db.collection("users").document(userId).collection("friend_requests").order(by: "createdAt", descending: true)
        let reg = query.addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let items: [FriendRequest] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let displayName = data["fromDisplayName"] as? String,
                      let created = (data["createdAt"] as? Timestamp)?.dateValue(),
                      let fromId = data["fromUid"] as? String else { return nil }
                let from = FriendUser(id: fromId, displayName: displayName, photoURL: data["fromPhotoURL"] as? String)
                return FriendRequest(id: doc.documentID, from: from, createdAt: created)
            }
            onChange(items)
        }
        return FirebaseListenerToken(inner: reg)
    }
}

enum FriendsServiceRouter {
    static func make() -> FriendsServiceProtocol { FriendsServiceFirestore() }
}
