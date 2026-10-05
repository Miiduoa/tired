# Tired｜Multi-role Task Planning for iOS

Tired 是一個以 **SwiftUI + Firebase** 實作的 iOS 任務管理原型，處理學生、工作、社團等多重角色下的課程、任務、行程與協作資料。

這個 repo 現在把重點放在兩件事：

1. iOS App 的資料模型與服務分層。
2. 可以獨立測試的排程規則，而不是只展示 UI。

## 可驗證的排程核心

`PlanningCore/` 是從 App 排程需求抽出的純 Swift Package，不依賴 SwiftUI 或 Firebase。

輸入包含：

- 任務預估分鐘數
- high / medium / low priority
- deadline day
- locked day
- busy blocks
- daily capacity

輸出包含：

- 每個任務被分配到哪一天
- 每日負載
- 無法排程的原因

目前測試涵蓋：

- 高優先級任務提早安排
- 不超過 deadline
- busy block 會吃掉每日容量
- locked task 不被移動
- 容量不足時明確跳過
- 已完成任務不再佔容量

執行：

```bash
swift test --package-path PlanningCore
```

GitHub Actions 只測這個純 Swift domain core，因此不需要 Firebase credential 或 iOS simulator。

## iOS App

主要程式在：

```text
tired/tired/tired/
  Models/
  Services/
  ViewModels/
  Views/
  Utils/
```

目前實作包含：

- Course / Enrollment
- Task / RecurringTask / TimeBlock
- Calendar
- Grade
- Organization / Membership
- Task dependencies
- Conflict detection
- Notifications
- AutoPlan UI
- Firebase Auth / Firestore / Storage boundary

`Utils/AutoPlanService.swift` 是 App 內原本的排程服務；`PlanningCore` 則提供一個更小、更容易驗證的規則核心。

## 為什麼另外抽 PlanningCore

完整 iOS App 同時依賴 UI、Firebase、日期環境與 Xcode 專案設定。若只靠 App 手動操作，很難判斷排程規則有沒有被改壞。

把核心規則抽成純 Swift 後，可以把：

```text
priority + deadline + capacity + busy time
                    ↓
               assignment
                    ↓
            deterministic tests
```

獨立驗證。

## Firebase

這個 repo 不把 Firebase client config 當成機密憑證；真正的資料存取邊界仍必須由 Firestore / Storage rules 與後端權限控制。

規則文件放在：

- `firestore.rules`
- `docs/FIRESTORE_RULES.md`

## 限制

- `PlanningCore` 是 weekly capacity heuristic，不是最佳化求解器。
- 目前 CI 驗證 domain core，不代表完整 Xcode App 已在 CI 編譯。
- Firebase 相關功能需要自行設定專案。
- 排程分數是透明規則，不宣稱為 AI。
- iOS App 還有較多功能面，這個 README 只列目前可從程式碼直接驗證的部分。

## Stack

`Swift` · `SwiftUI` · `Firebase` · `Cloud Functions` · `GitHub Actions`
