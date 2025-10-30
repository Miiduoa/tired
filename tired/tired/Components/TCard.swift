
import SwiftUI

struct TCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailingSystemImage: String?
    @ViewBuilder var content: Content
    
    init(title: String, subtitle: String? = nil, trailingSystemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailingSystemImage = trailingSystemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let s = subtitle { Text(s).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer()
                if let icon = trailingSystemImage {
                    Image(systemName: icon).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 8)
    }
}
