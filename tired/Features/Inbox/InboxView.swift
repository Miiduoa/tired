
import SwiftUI

struct InboxItem: Identifiable {
    enum Kind { case ack, rollcall, clockin, assignment }
    var id = UUID()
    var kind: Kind
    var title: String
    var subtitle: String
    var deadline: Date?
}

struct InboxView: View {
    @State var items: [InboxItem] = [
        .init(kind: .ack, title: "系上公告：11/10 停電", subtitle: "需回覆「已知悉」", deadline: .now.addingTimeInterval(60*60*24)),
        .init(kind: .rollcall, title: "資料庫課點名（H501）", subtitle: "倒數 09:30", deadline: .now.addingTimeInterval(60*10)),
        .init(kind: .assignment, title: "演算法作業#3", subtitle: "D-2 截止 23:59", deadline: .now.addingTimeInterval(60*60*24*2))
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        NavigationLink {
                            InboxDetailView(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: item.kind))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.body)
                                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let d = item.deadline {
                                    Text(shortDeadline(d))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } header: { Text("待處理") }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("收件匣")
        }
    }
    
    func icon(for k: InboxItem.Kind) -> String {
        switch k {
        case .ack: return "checkmark.seal"
        case .rollcall: return "qrcode.viewfinder"
        case .clockin: return "mappin.and.ellipse"
        case .assignment: return "doc.text"
        }
    }
    
    func shortDeadline(_ d: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: d)
    }
}

struct InboxDetailView: View {
    let item: InboxItem
    var body: some View {
        VStack(spacing: 24) {
            TCard(title: item.title, subtitle: item.subtitle, trailingSystemImage: "info.circle") {
                if let d = item.deadline {
                    Label("截止 \(d.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            
            Button("已知悉") { /* TODO: call ack */ }
                .gradientPrimary()
            
            Spacer()
        }
        .padding(16)
        .navigationTitle("詳情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.bg.ignoresSafeArea())
    }
}
