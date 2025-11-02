import SwiftUI

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
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published private(set) var queue: [ToastMessage] = []
    private var isPresenting = false
    private init() {}
    
    func show(_ text: String, style: ToastStyle = .info, haptics: Bool = true) {
        let msg = ToastMessage(text: text, style: style)
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
        HStack(spacing: 12) {
            Image(systemName: msg.style.icon)
                .foregroundStyle(msg.style.color)
            Text(msg.text)
                .foregroundStyle(Color.labelPrimary)
                .font(.subheadline)
            Spacer(minLength: 0)
            Button {
                withAnimation(TTokens.animationQuick) { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.separator.opacity(0.3), lineWidth: 0.6)
        }
        .shadow(color: TTokens.shadowLevel1.color, radius: TTokens.shadowLevel1.radius, y: TTokens.shadowLevel1.y)
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

