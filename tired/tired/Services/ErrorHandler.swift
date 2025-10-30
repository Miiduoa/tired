
import Foundation
import FirebaseAuth

/// 統一的錯誤處理工具
enum ErrorHandler {
    // MARK: - 錯誤訊息映射
    
    static func localizedMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        // Firebase Auth 錯誤
        if nsError.domain == AuthErrorDomain {
            return authErrorMessage(for: nsError)
        }
        
        return nsErrorMessage(for: nsError)
    }
    
    // MARK: - Firebase Auth 錯誤
    
    private static func authErrorMessage(for nsError: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return nsError.localizedDescription
        }
        
        switch code {
        case .networkError:
            return "網路連線異常，請稍後再試。"
        case .userNotFound:
            return "找不到對應帳號，請檢查電子郵件。"
        case .wrongPassword:
            return "密碼不正確，請再試一次。"
        case .emailAlreadyInUse:
            return "此電子郵件已被使用。"
        case .credentialAlreadyInUse:
            return "此登入方式已綁定其他帳號。"
        case .invalidEmail:
            return "電子郵件格式不正確。"
        case .tooManyRequests:
            return "嘗試次數過多，請稍後再試。"
        case .internalError:
            return "Firebase 設定有誤，請聯絡系統管理員。"
        case .userDisabled:
            return "此帳號已被停用，請聯絡管理員。"
        case .operationNotAllowed:
            return "此操作不被允許，請聯絡管理員。"
        case .weakPassword:
            return "密碼強度不足，請使用更複雜的密碼。"
        case .requiresRecentLogin:
            return "為確保安全，請重新登入後再試。"
        default:
            return nsError.localizedDescription
        }
    }
    
    // MARK: - NSError 錯誤
    
    private static func nsErrorMessage(for error: NSError) -> String {
        // Apple Sign-In 錯誤
        if error.domain == "com.apple.AuthenticationServices.AuthorizationError" {
            return appleSignInErrorMessage(code: error.code)
        }
        
        // Google Sign-In 錯誤
        if error.domain == "com.google.GIDSignIn" || error.domain.contains("google") {
            return googleSignInErrorMessage(code: error.code)
        }
        
        // URL 錯誤
        if error.domain == NSURLErrorDomain {
            return urlErrorMessage(code: error.code)
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Apple Sign-In 錯誤
    
    private static func appleSignInErrorMessage(code: Int) -> String {
        switch code {
        case 1000:
            return "Apple 登入被取消或失敗，請重試。"
        case 1001:
            return "Apple 登入流程被中斷。"
        case 1002:
            return "Apple 登入設定有誤，請檢查 App 設定。"
        case 1003:
            return "Apple 登入憑證無效。"
        case 1004:
            return "Apple 登入失敗，請重試。"
        case 1005:
            return "Apple 登入被拒絕。"
        case 1006:
            return "Apple 登入憑證已過期。"
        case 1007:
            return "Apple 登入憑證格式錯誤。"
        case 1008:
            return "Apple 登入憑證已撤銷。"
        case 1009:
            return "Apple 登入憑證不匹配。"
        case 1010:
            return "Apple 登入憑證已存在。"
        default:
            return "Apple 登入發生錯誤，請重試。"
        }
    }
    
    // MARK: - Google Sign-In 錯誤
    
    private static func googleSignInErrorMessage(code: Int) -> String {
        switch code {
        case 400:
            return "Google 登入設定錯誤，請確認 CLIENT_ID 和 URL Scheme 是否正確配置。"
        case 401:
            return "Google 登入憑證無效或已過期。"
        case 403:
            return "Google 登入被拒絕，請確認已啟用 Google Sign-In。"
        case -1:
            return "Google 登入被取消。"
        default:
            return "Google 登入發生錯誤（錯誤碼: \(code)），請重試。"
        }
    }
    
    // MARK: - URL 錯誤
    
    private static func urlErrorMessage(code: Int) -> String {
        switch code {
        case NSURLErrorNotConnectedToInternet:
            return "網路連線中斷，請檢查您的網路設定。"
        case NSURLErrorTimedOut:
            return "連線逾時，請稍後再試。"
        case NSURLErrorCannotFindHost:
            return "找不到伺服器，請確認網路連線。"
        case NSURLErrorCannotConnectToHost:
            return "無法連線到伺服器，請稍後再試。"
        default:
            return "網路錯誤，請稍後再試。"
        }
    }
    
    // MARK: - 錯誤分類
    
    enum ErrorCategory {
        case network
        case authentication
        case authorization
        case validation
        case server
        case unknown
    }
    
    static func categorize(_ error: Error) -> ErrorCategory {
        let nsError = error as NSError
        
        // Firebase Auth 錯誤
        if nsError.domain == AuthErrorDomain {
            guard let code = AuthErrorCode(rawValue: nsError.code) else {
                return .unknown
            }
            
            switch code {
            case .networkError:
                return .network
            case .userNotFound, .wrongPassword:
                return .authentication
            case .userDisabled, .operationNotAllowed:
                return .authorization
            case .invalidEmail, .weakPassword:
                return .validation
            default:
                return .unknown
            }
        }
        
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        
        return .unknown
    }
    
    // MARK: - 可恢復性檢查
    
    static func isRecoverable(_ error: Error) -> Bool {
        let category = categorize(error)
        switch category {
        case .network:
            return true // 網路錯誤通常可恢復
        case .authentication:
            return false // 認證錯誤需要用戶操作
        case .authorization:
            return false // 授權錯誤需要管理員操作
        case .validation:
            return true // 驗證錯誤可通過修正輸入恢復
        case .server:
            return true // 伺服器錯誤可能暫時性
        case .unknown:
            return false
        }
    }
}
