import SwiftUI

@available(iOS 17.0, *)
struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isSelected ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [color.opacity(0.95), color.opacity(0.75)]
                            : [Color.white.opacity(0.35), Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(AppDesignSystem.surfaceGradient.opacity(isSelected ? 0.25 : 0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.3) : AppDesignSystem.glassOverlay, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(isSelected ? "已選擇" : "點一下來選擇")
    }
}
