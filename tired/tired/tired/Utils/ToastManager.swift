import Foundation
import SwiftUI
import Combine

enum ToastType {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    var duration: TimeInterval = 3.0 // Default duration
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: Toast?
    private var workItem: DispatchWorkItem?

    private init() {}

    func showToast(message: String, type: ToastType, duration: TimeInterval = 3.0) {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel any existing toast dismissal
            self.workItem?.cancel()

            withAnimation {
                self.currentToast = Toast(message: message, type: type, duration: duration)
            }

            let newWorkItem = DispatchWorkItem { [weak self] in
                withAnimation {
                    self?.currentToast = nil
                }
            }
            self.workItem = newWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: newWorkItem)
        }
    }
}

// MARK: - View Modifier for presenting toasts

struct ToastModifier: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if let toast = toastManager.currentToast {
                VStack {
                    Spacer()
                    ToastView(toast: toast)
                        .padding(.horizontal)
                        .padding(.bottom, 20) // Adjust as needed
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(alignment: .center, spacing: AppDesignSystem.paddingSmall) {
            Image(systemName: toast.type.iconName)
                .foregroundColor(toast.type.tintColor)
                .font(.title2)
            Text(toast.message)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Material.regular)
        .cornerRadius(AppDesignSystem.cornerRadiusLarge)
        .shadow(radius: 5)
    }
}

// MARK: - Convenience View Extension

extension View {
    func withToastMessages() -> some View {
        self.modifier(ToastModifier())
    }
}
