import Foundation
import os.log

/// 統一日誌管理器
/// 使用 Apple 的 os.log 框架進行日誌記錄
final class AppLogger {

    // MARK: - Shared Instance

    static let shared = AppLogger()

    // MARK: - Log Categories

    private let authLog = OSLog(subsystem: "app.tired", category: "Auth")
    private let taskLog = OSLog(subsystem: "app.tired", category: "Tasks")
    private let orgLog = OSLog(subsystem: "app.tired", category: "Organizations")
    private let feedLog = OSLog(subsystem: "app.tired", category: "Feed")
    private let eventLog = OSLog(subsystem: "app.tired", category: "Events")
    private let storageLog = OSLog(subsystem: "app.tired", category: "Storage")
    private let generalLog = OSLog(subsystem: "app.tired", category: "General")

    private init() {}

    // MARK: - Logging Methods

    /// 記錄調試信息
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        os_log(.debug, log: log(for: category), "[DEBUG] %{public}@ - %{public}@:%d - %{public}@", fileName, function, line, message)
        #endif
    }

    /// 記錄一般信息
    func info(_ message: String, category: LogCategory = .general) {
        os_log(.info, log: log(for: category), "[INFO] %{public}@", message)
    }

    /// 記錄警告信息
    func warning(_ message: String, category: LogCategory = .general) {
        os_log(.default, log: log(for: category), "[WARNING] %{public}@", message)
    }

    /// 記錄錯誤信息
    func error(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error = error {
            os_log(.error, log: log(for: category), "[ERROR] %{public}@ - %{public}@", message, error.localizedDescription)
        } else {
            os_log(.error, log: log(for: category), "[ERROR] %{public}@", message)
        }
    }

    /// 記錄成功信息
    func success(_ message: String, category: LogCategory = .general) {
        os_log(.info, log: log(for: category), "[SUCCESS] %{public}@", message)
    }

    // MARK: - Helper Methods

    private func log(for category: LogCategory) -> OSLog {
        switch category {
        case .auth: return authLog
        case .tasks: return taskLog
        case .organizations: return orgLog
        case .feed: return feedLog
        case .events: return eventLog
        case .storage: return storageLog
        case .general: return generalLog
        }
    }
}

// MARK: - Log Category

enum LogCategory {
    case auth
    case tasks
    case organizations
    case feed
    case events
    case storage
    case general
}

// MARK: - Global Logging Functions

/// 便捷的全局日誌函數
func logDebug(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.debug(message, category: category)
}

func logInfo(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.info(message, category: category)
}

func logWarning(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.warning(message, category: category)
}

func logError(_ message: String, error: Error? = nil, category: LogCategory = .general) {
    AppLogger.shared.error(message, error: error, category: category)
}

func logSuccess(_ message: String, category: LogCategory = .general) {
    AppLogger.shared.success(message, category: category)
}

// MARK: - Error Types

/// 應用程式錯誤類型
enum AppError: LocalizedError {
    case userNotLoggedIn
    case invalidData
    case networkError(underlying: Error)
    case firebaseError(underlying: Error)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "用戶未登入"
        case .invalidData:
            return "數據格式錯誤"
        case .networkError(let error):
            return "網絡錯誤：\(error.localizedDescription)"
        case .firebaseError(let error):
            return "數據庫錯誤：\(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Alert Helper

import SwiftUI

/// 警告信息顯示助手
class AlertHelper: ObservableObject {
    static let shared = AlertHelper()

    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    private init() {}

    func showError(_ message: String, title: String = "錯誤") {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
    }

    func showSuccess(_ message: String, title: String = "成功") {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
    }

    func showInfo(_ message: String, title: String = "提示") {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
    }
}

// MARK: - View Extension for Alerts

extension View {
    func withAppAlert() -> some View {
        modifier(AppAlertModifier())
    }
}

struct AppAlertModifier: ViewModifier {
    @ObservedObject var alertHelper = AlertHelper.shared

    func body(content: Content) -> some View {
        content
            .alert(alertHelper.alertTitle, isPresented: $alertHelper.showAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(alertHelper.alertMessage)
            }
    }
}
