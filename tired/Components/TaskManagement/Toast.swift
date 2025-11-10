import SwiftUI

// MARK: - Toast Model
struct Toast: Identifiable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: TimeInterval

    enum ToastType {
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

    init(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 20))
                .foregroundColor(toast.type.color)

            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(3)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                dismiss()
            }
        }
        .onTapGesture {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            offset = -100
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Toast Manager
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: Toast?

    private init() {}

    func show(_ type: Toast.ToastType, message: String, duration: TimeInterval = 3.0) {
        // Dismiss current toast first if exists
        if currentToast != nil {
            currentToast = nil
        }

        // Show new toast with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentToast = Toast(type: type, message: message, duration: duration)
        }
    }

    func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(.success, message: message, duration: duration)
    }

    func showError(_ message: String, duration: TimeInterval = 3.0) {
        show(.error, message: message, duration: duration)
    }

    func showWarning(_ message: String, duration: TimeInterval = 3.0) {
        show(.warning, message: message, duration: duration)
    }

    func showInfo(_ message: String, duration: TimeInterval = 3.0) {
        show(.info, message: message, duration: duration)
    }

    func dismiss() {
        currentToast = nil
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let toast = toastManager.currentToast {
                ToastView(toast: toast) {
                    toastManager.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
                .padding(.top, 60) // Below navigation bar
            }
        }
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastModifier())
    }
}

// MARK: - Preview
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
        .overlay(alignment: .top) {
            ToastView(toast: Toast(type: .success, message: "任務已完成！")) {
                print("Dismissed")
            }
            .padding(.top, 60)
        }
    }
}
