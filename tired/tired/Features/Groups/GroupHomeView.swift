
import SwiftUI

struct GroupHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                    TCard(title: "廣播", subtitle: "今日 2 則", trailingSystemImage: "megaphone") {
                        HStack {
                            Text("查看最新公告與需回條").font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    TCard(title: "10 秒點名", subtitle: "資料庫 H501", trailingSystemImage: "qrcode.viewfinder") {
                        Button("開始點名") { }
                            .tPrimaryButton(fullWidth: true)
                    }
                    TCard(title: "打卡", subtitle: "資管系辦公室", trailingSystemImage: "mappin.circle") {
                        Button("到站打卡") { }
                            .tPrimaryButton(fullWidth: true)
                    }
                    TCard(title: "ESG 月報", subtitle: "11 月待上傳帳單", trailingSystemImage: "leaf") {
                        HStack(spacing: TTokens.spacingSM) {
                            Button("上傳帳單") { }
                                .tPrimaryButton()
                            Button("查看報告") { }
                                .tSecondaryButton()
                        }
                    }
                }
                .standardPadding()
            }
            .navigationTitle("群組")
            .background(Color.bg.ignoresSafeArea())
        }
    }
}
