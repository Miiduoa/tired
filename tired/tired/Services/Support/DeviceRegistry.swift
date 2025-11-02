import Foundation
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum DeviceRegistry {
    static func saveAPNSToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "APNSDeviceToken")
        await registerCurrentDevice()
    }

    static func registerCurrentDevice() async {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        #else
        return
        #endif
        guard let token = UserDefaults.standard.string(forKey: "APNSDeviceToken") else { return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("devices").document(token)
        let payload: [String: Any] = [
            "platform": "ios",
            "apnsToken": token,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        _ = try? await ref.setData(payload, merge: true)
    }
}

