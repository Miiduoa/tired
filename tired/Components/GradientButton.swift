
import SwiftUI

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background {
                TTokens.gradient
                    .opacity(configuration.isPressed ? 0.85 : 1.0)
                    .clipShape(RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.12), radius: 12, y: 8)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension Button where Label == Text {
    func gradientPrimary() -> some View { self.buttonStyle(GradientButtonStyle()) }
}
