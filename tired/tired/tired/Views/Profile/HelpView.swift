import SwiftUI

// MARK: - Help View

@available(iOS 17.0, *)
struct HelpView: View {
    var body: some View {
        List {
            Section("常見問題") {
                NavigationLink("如何創建組織？") {
                    HelpDetailView(
                        title: "如何創建組織？",
                        content: """
                        創建組織步驟：

                        1. 前往「組織」頁面
                        2. 點擊右上角的「+」按鈕
                        3. 填寫組織名稱和類型
                        4. 選擇組織類型（學校、公司、社團等）
                        5. 添加組織描述（選填）
                        6. 點擊「創建」按鈕

                        創建後，您將自動成為該組織的擁有者，可以：
                        • 邀請其他成員加入
                        • 管理成員角色
                        • 發布組織動態
                        • 創建活動和任務
                        • 啟用小應用（任務看板、活動報名等）
                        """
                    )
                }

                NavigationLink("如何使用自動排程？") {
                    HelpDetailView(
                        title: "如何使用自動排程？",
                        content: """
                        自動排程功能說明：

                        什麼是自動排程？
                        自動排程（AutoPlan）會智能地將您的待辦任務分配到合適的日期。

                        使用步驟：
                        1. 前往「任務」頁面
                        2. 確保有待排程的任務（Backlog中的任務）
                        3. 點擊工具列中的「自動排程」按鈕
                        4. 系統會根據以下因素自動分配：
                           • 任務的截止日期
                           • 任務的優先級
                           • 每日時間容量設定
                           • 已鎖定日期的任務

                        提示：
                        • 在「設定 > 時間管理」中調整每日/每週容量
                        • 為重要任務設定截止日期以獲得更好的排程效果
                        • 使用「鎖定日期」功能防止特定任務被重新排程
                        """
                    )
                }

                NavigationLink("如何報名活動？") {
                    HelpDetailView(
                        title: "如何報名活動？",
                        content: """
                        活動報名步驟：

                        1. 前往您已加入的組織頁面
                        2. 切換到「小應用」標籤
                        3. 點擊「活動報名」應用
                        4. 瀏覽可用的活動列表
                        5. 點擊想要參加的活動的「立即報名」按鈕

                        報名成功後：
                        • 活動會顯示「已報名」標記
                        • 系統會自動在您的任務中創建活動提醒
                        • 您可以在「我的 > 我的活動」查看所有報名的活動

                        取消報名：
                        • 在活動詳情頁點擊「取消報名」按鈕
                        • 相關的任務提醒也會自動刪除
                        """
                    )
                }

                NavigationLink("如何同步組織任務？") {
                    HelpDetailView(
                        title: "如何同步組織任務？",
                        content: """
                        同步組織任務步驟：

                        1. 前往組織頁面，點擊「小應用」標籤
                        2. 進入「任務看板」應用
                        3. 瀏覽組織發布的任務
                        4. 點擊任務旁的「同步到個人」按鈕

                        同步後的任務：
                        • 會出現在您的任務中樞
                        • 可以設定個人的計劃日期
                        • 可以標記完成狀態
                        • 保留與組織任務的關聯

                        注意事項：
                        • 組織管理員可以查看任務完成情況
                        • 同步的任務會標記來源組織
                        """
                    )
                }
            }

            Section("使用技巧") {
                NavigationLink("任務分類說明") {
                    HelpDetailView(
                        title: "任務分類說明",
                        content: """
                        Tired 支援四種任務分類：

                        🔵 學校
                        適用於：課程作業、考試準備、報告撰寫等學業相關任務

                        🔴 工作
                        適用於：專案任務、會議準備、工作報告等職場相關任務

                        🟣 社團
                        適用於：社團活動、志工服務、課外活動等社團相關任務

                        🟢 生活
                        適用於：個人事務、生活瑣事、休閒活動等個人生活任務

                        選擇正確的分類可以幫助您：
                        • 更好地統計各領域的時間分配
                        • 按分類篩選和查看任務
                        • 了解自己在不同身份上的投入
                        """
                    )
                }

                NavigationLink("優先級使用建議") {
                    HelpDetailView(
                        title: "優先級使用建議",
                        content: """
                        任務優先級說明：

                        🔴 高優先級
                        • 緊急且重要的任務
                        • 有嚴格截止日期的任務
                        • 會影響其他工作的前置任務

                        🟡 中優先級
                        • 重要但不緊急的任務
                        • 有彈性截止日期的任務
                        • 常規工作任務

                        🟢 低優先級
                        • 可以延後處理的任務
                        • 沒有明確截止日期的任務
                        • 日常瑣事

                        建議：
                        • 避免所有任務都設為高優先級
                        • 定期檢視和調整優先級
                        • 優先完成高優先級任務
                        """
                    )
                }
            }

            Section("聯繫我們") {
                Button {
                    if let url = URL(string: "mailto:support@tired.app") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("發送郵件", systemImage: "envelope.fill")
                }

                Button {
                    if let url = URL(string: "https://github.com/Miiduoa/tired/issues") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("反饋問題", systemImage: "exclamationmark.bubble.fill")
                }
            }
        }
        .navigationTitle("幫助與支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Detail View

@available(iOS 17.0, *)
struct HelpDetailView: View {
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
