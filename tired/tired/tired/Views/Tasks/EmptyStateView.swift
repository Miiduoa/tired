import SwiftUI

@available(iOS 17.0, *)
struct EmptyStateView: View {
    var icon: String = "checkmark.circle"
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(message)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesignSystem.paddingLarge * 2)
        .glassmorphicCard()
    }
}
