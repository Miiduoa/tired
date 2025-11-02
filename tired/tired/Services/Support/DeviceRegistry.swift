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

    static func saveFCMToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: "FCMToken")
        await registerCurrentDevice()
    }

    static func registerCurrentDevice() async {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        #else
        return
        #endif
        let apns = UserDefaults.standard.string(forKey: "APNSDeviceToken")
        let fcm = UserDefaults.standard.string(forKey: "FCMToken")
        guard apns != nil || fcm != nil else { return }
        let db = Firestore.firestore()
        // Use APNS token as id if available, else FCM token
        let docId = apns ?? fcm!
        let ref = db.collection("users").document(uid).collection("devices").document(docId)
        let payload: [String: Any] = [
            "platform": "ios",
            "apnsToken": apns ?? "",
            "fcmToken": fcm ?? "",
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        _ = try? await ref.setData(payload, merge: true)
    }
}
