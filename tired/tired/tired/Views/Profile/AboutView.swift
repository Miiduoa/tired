import SwiftUI

// MARK: - About View

@available(iOS 17.0, *)
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("構建號")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Text("Tired 是一個專為現代斜槓青年設計的多身份任務管理應用。支持學校、工作、社團等多種身份的任務統籌與智能排程。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } header: {
                Text("關於應用")
            }

            Section("主要功能") {
                FeatureRow(icon: "checkmark.circle.fill", color: .green, title: "任務管理", description: "創建、排程和追蹤多身份任務")
                FeatureRow(icon: "calendar.badge.clock", color: .orange, title: "智能排程", description: "自動分配任務到合適的時間段")
                FeatureRow(icon: "building.2.fill", color: .purple, title: "組織管理", description: "加入組織，接收任務和活動通知")
                FeatureRow(icon: "person.2.fill", color: .blue, title: "活動報名", description: "查看和報名組織舉辦的活動")
            }

            Section("法律條款") {
                NavigationLink {
                    LegalDocumentView(title: "隱私政策", content: privacyPolicyContent)
                } label: {
                    Label("隱私政策", systemImage: "hand.raised.fill")
                }

                NavigationLink {
                    LegalDocumentView(title: "服務條款", content: termsOfServiceContent)
                } label: {
                    Label("服務條款", systemImage: "doc.text.fill")
                }

                NavigationLink {
                    LegalDocumentView(title: "開源許可", content: openSourceLicensesContent)
                } label: {
                    Label("開源許可", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Section {
                Text("© 2024 Tired App. All rights reserved.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("關於 Tired")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyPolicyContent: String {
        """
        隱私政策

        最後更新日期：2024年1月

        1. 資訊收集
        我們收集以下類型的資訊：
        • 帳戶資訊：您的電子郵件地址和顯示名稱
        • 任務資料：您創建的任務、排程和完成狀態
        • 組織資訊：您加入的組織和會員身份
        • 使用數據：應用程式的使用情況和偏好設定

        2. 資訊使用
        我們使用收集的資訊來：
        • 提供和維護我們的服務
        • 改善用戶體驗
        • 發送服務相關通知

        3. 資訊保護
        我們採用業界標準的安全措施來保護您的個人資訊。

        4. 聯繫我們
        如有任何問題，請發送郵件至 support@tired.app
        """
    }

    private var termsOfServiceContent: String {
        """
        服務條款

        最後更新日期：2024年1月

        1. 接受條款
        使用 Tired 應用程式即表示您同意這些服務條款。

        2. 服務描述
        Tired 是一個任務管理和排程應用程式，幫助用戶管理多種身份下的任務和活動。

        3. 用戶責任
        • 您負責維護帳戶安全
        • 您同意不濫用服務
        • 您對上傳的內容負責

        4. 隱私
        您的隱私對我們很重要。請參閱我們的隱私政策了解詳情。

        5. 服務變更
        我們保留隨時修改或終止服務的權利。

        6. 免責聲明
        服務按「現狀」提供，不做任何形式的保證。
        """
    }

    private var openSourceLicensesContent: String {
        """
        開源許可

        Tired 使用了以下開源軟體：

        Firebase iOS SDK
        Apache License 2.0
        https://github.com/firebase/firebase-ios-sdk

        Google Sign-In for iOS
        Apache License 2.0
        https://github.com/google/GoogleSignIn-iOS

        Swift
        Apache License 2.0
        https://github.com/apple/swift

        感謝所有開源貢獻者的付出！
        """
    }
}


// MARK: - Feature Row

@available(iOS 17.0, *)
struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Legal Document View

@available(iOS 17.0, *)
struct LegalDocumentView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14))
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
