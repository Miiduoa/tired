import SwiftUI

@available(iOS 17.0, *)
struct CategoryChip: View {
    let title: String
    var color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppDesignSystem.accentGradient)
                            .overlay(AppDesignSystem.surfaceGradient.opacity(0.25))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appSecondaryBackground)
                            .overlay(AppDesignSystem.surfaceGradient.opacity(0.4))
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.3) : AppDesignSystem.glassOverlay, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
