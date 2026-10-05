# Tired｜Planning Core for Multi-role Tasks

Tired 原本是一個 SwiftUI + Firebase 的多身份任務管理原型。這個 repo 現在把**可重現、可測試的部分**集中在 `PlanningCore/`，避免把尚未完整保存的 Xcode 專案包裝成可直接 build 的作品。

## 可驗證的核心

`PlanningCore/` 是純 Swift Package，不依賴 SwiftUI、Firebase 或 Xcode project metadata。

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

執行：

```bash
swift test --package-path PlanningCore
```

目前測試涵蓋：

- 高優先級任務提早安排
- 不超過 deadline
- busy block 會吃掉每日容量
- locked task 不被移動
- 容量不足時明確跳過
- 已完成任務不再佔容量

GitHub Actions 只測這個純 Swift domain core，因此不需要 Firebase credential 或 iOS simulator。

## iOS source snapshot

`tired/` 仍保留原本 App 的 Swift source，例如：

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

這些 source 可以用來查看資料模型、ViewModel、Service 與 UI 分層，但**目前 repository 沒有保存 `.xcodeproj`、`.xcworkspace` 或 `project.pbxproj`**，因此不能從乾淨 checkout 直接重建完整 iOS App。

這也是為什麼首頁只把 `PlanningCore` 當成可驗證成果，而不是把完整 App 的可執行性說得比實際更多。

## Planning model

核心可以簡化成：

```text
priority + deadline + capacity + busy time
                    ↓
               assignment
                    ↓
            deterministic tests
```

`PlanningCore` 是 weekly capacity heuristic，不是最佳化求解器，也不宣稱是 AI 排程。

## Firebase notes

App source 中仍保留 Firebase Auth / Firestore / Storage 邊界與規則文件：

- `firestore.rules`
- `docs/FIRESTORE_RULES.md`

Firebase client config 本身不是安全邊界；真正的資料存取仍應由 Security Rules 與後端權限控制。

## Scope

- 可重現成果：`PlanningCore` + tests
- iOS source：保留作架構與介面參考
- 完整 Xcode build：目前無法從 repo 直接重建
- CI：只驗證純 Swift domain core

## Stack

`Swift` · `Swift Package Manager` · `SwiftUI source` · `Firebase source` · `GitHub Actions`
