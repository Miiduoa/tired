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
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var db: Firestore {
        return Firestore.firestore()
    }

    var auth: Auth {
        return Auth.auth()
    }
}
