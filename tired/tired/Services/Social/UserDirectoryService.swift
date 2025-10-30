import Foundation
import FirebaseFirestore
import Combine

struct DirectoryUser: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let email: String
}

protocol UserDirectoryServiceProtocol {
    func fetchUsers(limit: Int) async -> [DirectoryUser]
}

final class UserDirectoryService: UserDirectoryServiceProtocol {
    private let db = Firestore.firestore()
    func fetchUsers(limit: Int) async -> [DirectoryUser] {
        do {
            let snap = try await db.collection("users").order(by: "displayName").limit(to: limit).getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                let name = data["displayName"] as? String ?? (data["email"] as? String ?? "User")
                let email = data["email"] as? String ?? ""
                return DirectoryUser(id: doc.documentID, displayName: name, email: email)
            }
        } catch {
            return []
        }
    }
}

