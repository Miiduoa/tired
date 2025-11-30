import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Firebase 初始化和配置管理
class FirebaseManager {
    static let shared = FirebaseManager()

    private init() {
        configure()
    }

    func configure() {
        // 確保 Firebase 只初始化一次
        guard FirebaseApp.app() == nil else {
            print("✅ Firebase 已經初始化")
            return
        }
        
        // 檢查 GoogleService-Info.plist 是否存在
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              FileManager.default.fileExists(atPath: path) else {
            print("❌ 錯誤: 找不到 GoogleService-Info.plist")
            return
        }

        print("✅ 找到 GoogleService-Info.plist: \(path)")
        FirebaseApp.configure()
        
        // 啟用離線 persistence
        let settings = FirestoreSettings()
        // isPersistenceEnabled is deprecated and enabled by default in newer SDKs or controlled via cacheSettings
        // settings.isPersistenceEnabled = true 
        // 設置快取大小為 100 MB
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
        Firestore.firestore().settings = settings
        
        print("✅ Firebase 初始化成功 (已啟用離線支援)")
    }

    var db: Firestore {
        return Firestore.firestore()
    }

    var auth: Auth {
        return Auth.auth()
    }
}
