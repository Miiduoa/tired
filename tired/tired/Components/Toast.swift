import SwiftUI
import Combine

enum ToastStyle {
    case success, warning, error, info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .tint
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle
    let actionTitle: String?
    let action: (() -> Void)?
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published private(set) var queue: [ToastMessage] = []
    private var isPresenting = false
    private init() {}
    
    func show(_ text: String, style: ToastStyle = .info, actionTitle: String? = nil, haptics: Bool = true, action: (() -> Void)? = nil) {
        let msg = ToastMessage(text: text, style: style, actionTitle: actionTitle, action: action)
        queue.append(msg)
        if haptics {
            switch style {
            case .success: Haptics.success()
            case .warning: Haptics.warning()
            case .error: Haptics.error()
            case .info: Haptics.impact(.light)
            }
        }
    }
    
    @discardableResult
    func pop() -> ToastMessage? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
}

struct ToastHostView: View {
    @EnvironmentObject private var center: ToastCenter
    @State private var current: ToastMessage? = nil
    @State private var visible = false
    
    var body: some View {
        ZStack {
            if let current {
                toastView(current)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .onChange(of: center.queue) { _ in
            showNextIfNeeded()
        }
        .onAppear { showNextIfNeeded() }
    }
    
    @ViewBuilder
    private func toastView(_ msg: ToastMessage) -> some View {
        HStack(spacing: 14) {
            // 圖標（增強視覺）
            ZStack {
                Circle()
                    .fill(msg.style.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: msg.style.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(msg.style.color)
            }
            
            // 訊息文字
            Text(msg.text)
                .foregroundStyle(Color.labelPrimary)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            
            Spacer(minLength: 0)
            
            // 行動按鈕
            if let title = msg.actionTitle, msg.action != nil {
                Button {
                    HapticFeedback.light()
                    msg.action?()
                    withAnimation(TTokens.animationQuick) { dismiss() }
                } label: {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(msg.style.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(msg.style.color.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // 關閉按鈕
            Button {
                HapticFeedback.selection()
                withAnimation(TTokens.animationQuick) { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.neutralLight.opacity(0.3), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(msg.style.color.opacity(0.2), lineWidth: 1)
                }
        }
        .shadow(color: msg.style.color.opacity(0.2), radius: 16, y: 8)
        .shadow(color: TTokens.shadowLevel2.color, radius: TTokens.shadowLevel2.radius, y: TTokens.shadowLevel2.y)
        .padding(.horizontal, 16)
    }
    
    private func showNextIfNeeded() {
        guard current == nil, let next = center.pop() else { return }
        withAnimation(TTokens.animationQuick) {
            current = next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(TTokens.animationQuick) { dismiss() }
        }
    }
    
    private func dismiss() {
        current = nil
        // 若還有下一筆，延遲一點再顯示，保證動畫順序
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showNextIfNeeded()
        }
    }
}
