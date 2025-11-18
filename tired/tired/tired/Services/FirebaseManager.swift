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
            print("   請確認檔案已添加到 Xcode 專案，並且 Target Membership 已勾選")
            fatalError("GoogleService-Info.plist 未找到。請確認檔案已正確添加到專案中。")
        }
        
        print("✅ 找到 GoogleService-Info.plist: \(path)")
        FirebaseApp.configure()
        print("✅ Firebase 初始化成功")
    }

    var db: Firestore {
        return Firestore.firestore()
    }

    var auth: Auth {
        return Auth.auth()
    }
}
