import SwiftUI

struct AppLoadingView: View {
    let title: String
    var body: some View {
        VStack(spacing: TTokens.spacingLG) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.tint)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.opacity(0.6))
    }
}

struct AppEmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: TTokens.spacingXL) {
            ZStack {
                Circle()
                    .fill(TTokens.gradientPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: systemImage)
                    .font(.system(size: 50))
                    .foregroundStyle(TTokens.gradientPrimary)
            }
            VStack(spacing: TTokens.spacingSM) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.opacity(0.6))
    }
}

struct AppErrorView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: TTokens.spacingLG) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button(L.s("action.retry")) { onRetry() }
                .tPrimaryButton()
        }
        .padding()
    }
}


