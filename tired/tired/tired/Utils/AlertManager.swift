import Foundation
import SwiftUI
import Combine

/// Alert 管理器
class AlertManager: ObservableObject {
    @Published var alert: AlertConfig?

    func showSuccess(_ message: String, title: String = "成功") {
        alert = AlertConfig(title: title, message: message, type: .success)
    }

    func showError(_ message: String, title: String = "錯誤") {
        alert = AlertConfig(title: title, message: message, type: .error)
    }

    func showWarning(_ message: String, title: String = "提示") {
        alert = AlertConfig(title: title, message: message, type: .warning)
    }

    func showInfo(_ message: String, title: String = "信息") {
        alert = AlertConfig(title: title, message: message, type: .info)
    }

    func dismiss() {
        alert = nil
    }
}

/// Alert 配置
struct AlertConfig: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: AlertType

    enum AlertType {
        case success
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
}

/// Alert View Modifier
struct AlertViewModifier: ViewModifier {
    @ObservedObject var alertManager: AlertManager

    func body(content: Content) -> some View {
        content
            .alert(item: $alertManager.alert) { config in
                Alert(
                    title: Text(config.title),
                    message: Text(config.message),
                    dismissButton: .default(Text("確定"))
                )
            }
    }
}

extension View {
    func withAlertManager(_ alertManager: AlertManager) -> some View {
        modifier(AlertViewModifier(alertManager: alertManager))
    }
}
