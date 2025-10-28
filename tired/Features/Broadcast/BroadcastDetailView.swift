
import SwiftUI

struct BroadcastDetailView: View {
    var title: String = "期中考換教室通知"
    var bodyText: String = "本週五 10:10 的資料庫期中考，教室改至 H 棟 501。請提前 10 分鐘入座，攜帶學生證。"
    var deadline: Date = .now.addingTimeInterval(60*60*24)
    
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title).font(.title2).bold()
                    Text(bodyText).font(.body)
                    HStack {
                        Image(systemName: "calendar")
                        Text("截止 " + deadline.formatted(date: .abbreviated, time: .shortened))
                    }.foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
                }
                .padding(.horizontal, 16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button("已知悉") { }
                        .gradientPrimary()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
    }
}
