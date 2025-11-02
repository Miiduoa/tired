import Foundation
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class SnoozeSyncService {
    static let shared = SnoozeSyncService()
    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    func syncFromRemote() async {
        guard let uid = uid else { return }
        do {
            let snap = try await db.collection("users").document(uid).collection("snoozes").getDocuments()
            for doc in snap.documents {
                let data = doc.data()
                if let ts = data["expiresAt"] as? Timestamp {
                    SnoozeStore.shared.snooze(id: doc.documentID, until: ts.dateValue())
                }
            }
        } catch {
            // ignore
        }
    }

    func saveSnooze(id: String, title: String, subtitle: String?, expires: Date, kind: String) async {
        guard let uid = uid else { return }
        let ref = db.collection("users").document(uid).collection("snoozes").document(id)
        let payload: [String: Any] = [
            "title": title,
            "subtitle": subtitle ?? "",
            "kind": kind,
            "expiresAt": Timestamp(date: expires),
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        _ = try? await ref.setData(payload, merge: true)
    }

    func clearSnooze(id: String) async {
        guard let uid = uid else { return }
        let ref = db.collection("users").document(uid).collection("snoozes").document(id)
        _ = try? await ref.delete()
    }
}

