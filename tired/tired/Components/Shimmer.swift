import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.0), location: 0.0),
                        .init(color: .white.opacity(0.4), location: 0.5),
                        .init(color: .white.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .mask(content)
                .opacity(0.8)
                .offset(x: phase * 220)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

struct FeedSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Color.neutralLight).frame(width: 28, height: 28).shimmer()
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.neutralLight).frame(height: 12).shimmer()
                    RoundedRectangle(cornerRadius: 6).fill(Color.neutralLight).frame(width: 120, height: 10).shimmer()
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 8).fill(Color.neutralLight).frame(height: 12).shimmer()
            RoundedRectangle(cornerRadius: 8).fill(Color.neutralLight).frame(height: 12).shimmer()
            RoundedRectangle(cornerRadius: 8).fill(Color.neutralLight).frame(width: 180, height: 12).shimmer()
        }
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusMD))
    }
}

