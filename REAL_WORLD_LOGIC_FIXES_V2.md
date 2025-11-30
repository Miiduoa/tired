# Tired App - 真實情境邏輯修正與缺漏功能設計（V2）

以下專注「真實使用場景」下仍存在的邏輯缺陷與缺失功能，附上發生位置、痛點、修正方向與驗收方式，便於直接排期落地。

---

## P0 需先修的邏輯問題

1) **被指派的組織任務顯示不到**
- **情境**：組織管理者建立任務並指派給 A、B。Firestore `tasks` 文檔的 `userId` 仍為建立者，`assigneeUserIds` 才包含 A/B。A 打開 App 時，`fetchTodayTasks/fetchWeekTasks/fetchBacklog` 只用 `userId == currentUserId` 查詢，導致 A 看不到自己的指派任務，無法完成/排程。
- **位置**：`tired/Services/TaskService.swift:16-114`（所有列表查詢都僅用 `userId`）。
- **修正方向**：雙通道查詢並合併去重  
  - 主要查詢：`whereField("userId", isEqualTo: userId)`（個人/自建任務）。  
  - 指派查詢：`whereField("assigneeUserIds", arrayContains: userId)`（組織派發/多人指派）。  
  - 合併後依 `id` 去重；所有視圖統一走合併結果。  
  - Firestore 索引：`assigneeUserIds` 需建立 array-contains 索引（production index）。
- **驗收**：A 不論是不是建立者，只要在 `assigneeUserIds` 都能在 Today/Week/Backlog 看到並操作；自動排程、提醒、成就計數均應包含被指派任務。

2) **自動排程與衝突檢測忽略「具體開始時間」，易與課表/會議撞時段**
- **情境**：週三 14:00-16:00 有會議（行事曆 Busy block）。Autoplan 只看「每日總分鐘」與 `plannedDate`，沒有寫入 `plannedStartTime`，也沒做時間段填充；`TaskConflictDetector` 在 `plannedStartTime` 缺失時用日期零點作為開始，衝突檢測結果失真。
- **位置**：`Utils/AutoPlanService.swift:59-170`（按日容量分配，無時間段）；`Services/TaskConflictDetector.swift:27-97`（若無具體時間即使用日期）；`Models/Task.swift` 已有 `plannedStartTime` 但未被自動排程填充。
- **修正方向**：落實「時間段」排程  
  - Autoplan 輸入 `busyBlocks` 後生成「30 分鐘槽」的可用時間線（含日容量、外部行事曆）。  
  - 為每個排上的任務寫入 `plannedStartTime`，並確保 `plannedStartTime + estimatedMinutes` 不落在 busy block 或其他任務的時間段。  
  - 衝突檢測改用 `plannedStartTime`；若缺省，回退到當日工作起始時間（例如使用者設定的工作開始 09:00），不可再用零點。  
  - UI：Today/Week 卡片顯示開始時間；拖移/調整時長時更新 `plannedStartTime`。
- **驗收**：帶具體會議的日子仍能排出不撞時段的任務；衝突檢測能精確指出 14:00-16:00 與 15:00-16:00 的重疊，而不是誤判為同日衝突或不報告。

3) **長任務不拆分，可能「排不上」或硬塞超載**
- **情境**：預估 300 分鐘的期末報告，日容量 240 分鐘。Autoplan 會在尋找合適日子時被 `newLoad > capacity*1.1` 擋掉，最後 fallback 直接塞到最空的日子，導致該日超載且沒有拆分。
- **位置**：`Utils/AutoPlanService.swift:113-150`（若找不到最佳日，會選負載最低日，未分段）；UI/模型尚無分片任務表示。
- **修正方向**：支援「拆分式排程」  
  - 新模型 `TaskSlice { parentTaskId, sliceIndex, plannedDate, plannedStartTime, minutes }` 或直接在 `Task` 中增加 `splitOfTaskId` 與 `splitIndex`。  
  - Autoplan 遇到 `estimatedMinutes > dailyCapacity` 或某日剩餘容量不足時，自動切成多段分散排程，並在父任務顯示彙總進度。  
  - 完成邏輯：父任務完成 = 所有 slice 完成；刪除/改期須同步所有未完成 slice。  
  - UI：在日卡顯示「(1/3) 期末報告 90m」並可集中查看父任務。
- **驗收**：300 分鐘任務會被拆成數段並分散多日；日容量不再被單一任務硬塞爆；父子任務完成狀態一致。

4) **跨時區/多裝置時，今天/逾期判斷會錯位**
- **情境**：用戶在美西建立「今天」任務，晚間飛到台灣，打開 App 會被判定為「已過期」或「非今天」。`Calendar.current` 使用裝置時區，未使用 `UserProfile.timezone`。提醒與通知也跟著錯位。
- **位置**：`Models/Task.swift` 的 `isTaskForToday/isThisWeek/isOverdue`，`Services/TaskService.computeIsToday`，`NotificationService.scheduleNotification`，均直接用 `Calendar.current` / 本地時間。
- **修正方向**：統一使用「用戶時區」  
  - 在 `UserProfile` 已有 `timezone`；建立 `AppTimezone.currentUserCalendar`，所有日期比較與通知觸發改用該 Calendar。  
  - 存儲層：保存 UTC `Date` + 用戶時區字串；展示時才轉換。  
  - 提醒：`UNCalendarNotificationTrigger` 轉成用戶時區的 date components，並在切換帳號或時區時重排通知。
- **驗收**：跨時區後，Today/Week/Overdue 結果一致；通知在用戶當地時間準時彈出。

5) **Autoplan 只能從「今天」開始，無法提前排下週**
- **情境**：週五想先排下週，`AutoPlanView.generatePreview` 與 `AutoPlanService.AutoPlanOptions` 都從 `Date()` 開始迭代 14 天，無法指定下週的 weekStart，導致所有未排程任務被塞到本週末或今天。
- **位置**：`Views/Tasks/AutoPlanView.swift:394-452`（預覽從 today 起 14 天），`Utils/AutoPlanService.swift` 的 options 預設 weekStart 為當週。
- **修正方向**：允許選擇目標週  
  - AutoPlan UI 加入「排程起始日」選擇（預設下個週一）。  
  - `AutoPlanOptions` 使用該起始日，`availableDays` 也從選定日期起算 7~14 天。  
  - 今日任務若被提前排到未來，需提示「將離開今日清單」。  
  - 週視圖可切換週期並套用同樣的 autoplan 起點。
- **驗收**：在週五選「下週一開始」後，預覽與實際排程都落在下週；今日視圖不會被強行塞滿。

---

## 尚未涵蓋但真實需要的功能設計

1) **任務指派的「接受/拒絕」流程**
- **痛點**：多人協作時，指派即視為接受，A 可能沒看過就被計入週容量，導致排程錯誤。
- **設計**：  
  - 模型：新增 `assignmentStatus: pending/accepted/declined`, `assignedBy`, `acceptedAt`, `declinedReason?`。  
  - 流程：指派 → A 收到推播 + Inbox 條目 → A 點擊「接受並排程」或「拒絕（填理由）」；拒絕會通知指派者並解除 `assigneeUserIds`。  
  - Autoplan：只排 `accepted` 的任務；`pending` 仍可預覽但需提示「等待接受」。  
  - UI：Today/Week 卡片加「需接受」標籤；TaskDetail 顯示指派人與回覆按鈕。
- **驗收**：未接受的任務不佔容量；拒絕有記錄並通知；接受後自動進入排程。

2) **身份化的可用時段與地點限制**
- **痛點**：學生任務只能在課後、打工任務只能在店內；目前只有日容量，沒有身份/地點約束。
- **設計**：  
  - 模型：`IdentitySchedulePreference { organizationId, roleId, weekdays: [Int], availableWindows: [TimeRange], dailyCapMinutes, locationConstraint? }`。  
  - Autoplan：按任務的 `sourceOrgId` 匹配對應偏好，只在允許的時間窗填充；若無可用窗，回傳提示並要求使用者手動決策。  
  - 地點：可選的「需要到場」任務，使用粗粒度定位檢查是否在允許地點（可選開關，並尊重隱私）。  
  - UI：設定頁可為每個身份設定可用時段；任務卡片顯示使用的規則來源。
- **驗收**：社團任務不會被排進工作時段；若無可用時段，Autoplan 彈出需要手動調整的提示。

3) **離線/弱網可靠性（操作隊列 + 復原）**
- **痛點**：地鐵/校園弱網下操作可能丟失；目前完全依賴即時 Firestore，沒有本地冪等機制。
- **設計**：  
  - 本地存儲：用 SwiftData/SQLite 保存 `PendingOperation { type, taskSnapshot, timestamp, retryCount }`。  
  - 重放：網路恢復後按時間順序重放；若遠端已變更，提供「以遠端為準 / 以本地覆蓋 / 合併」三選。  
  - UI：頂部橫幅提示「離線模式，X 個操作待同步」；每筆待同步任務加上「待同步」徽章。  
  - 冪等：為每筆操作附 `clientRequestId`，雲端接受後回傳以防重覆寫入。
- **驗收**：斷網新增/完成/改期後重新上線，數據保持一致且不重覆；衝突有明確提示與手動決策。

4) **實際耗時回填與估算修正**
- **痛點**：`Task.actualMinutes` 已存在但未使用，估時長期不準確，Autoplan 仍以舊估算排程。
- **設計**：  
  - 完成任務時提示「實際花了多久？」或從專注計時自動回填。  
  - 建立 `EstimateModel`：按任務類別、優先級、任務類型統計「估計/實際」比值，週期性更新，並在建立/排程時給出建議估時。  
  - UI：在任務詳情顯示「平均超時 +20%」提示，提供一鍵調整估時。
- **驗收**：完成後能看到估時 vs 實際；重新建立同類任務時的預設估時會根據歷史自動調整。

---

**實施順序建議**：先處理 P0 中的 1/2/4/5（能直接修復錯誤行為），接著做 P0-3 的拆分排程。功能新增可依 1 → 2 → 3 → 4 逐步迭代，確保協作可靠性與排程精度同步提升。
