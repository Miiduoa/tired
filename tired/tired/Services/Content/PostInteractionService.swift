import Foundation
import FirebaseFirestore

protocol PostInteractionServiceProtocol {
    func isLiked(postId: String, userId: String) async -> Bool
    func like(postId: String, userId: String) async
    func unlike(postId: String, userId: String) async
    func likeCount(postId: String) async -> Int
}

final class PostInteractionService: PostInteractionServiceProtocol {
    private let db = Firestore.firestore()
    
    func isLiked(postId: String, userId: String) async -> Bool {
        let ref = db.collection("posts").document(postId).collection("likes").document(userId)
        do { return try await ref.getDocument().exists } catch { return false }
    }
    
    func like(postId: String, userId: String) async {
        let ref = db.collection("posts").document(postId).collection("likes").document(userId)
        _ = try? await ref.setData(["uid": userId, "createdAt": FieldValue.serverTimestamp()])
    }
    
    func unlike(postId: String, userId: String) async {
        let ref = db.collection("posts").document(postId).collection("likes").document(userId)
        try? await ref.delete()
    }
    
    func likeCount(postId: String) async -> Int {
        let ref = db.collection("posts").document(postId).collection("likes")
        do { let snap = try await ref.limit(to: 500).getDocuments(); return snap.count } catch { return 0 }
    }
}


