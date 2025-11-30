# 真實使用情境分析與改進計劃

## 📋 目錄
1. [真實使用情境分析](#真實使用情境分析)
2. [發現的邏輯問題](#發現的邏輯問題)
3. [缺失的功能](#缺失的功能)
4. [詳細改進方案](#詳細改進方案)
5. [實施優先級](#實施優先級)

---

## 真實使用情境分析

### 情境 1: 大學生 - 多身份任務管理

**用戶背景：**
- 學生（學校身份）
- 實習生（公司身份）
- 社團幹部（社團身份）

**典型一天：**
```
08:00 - 上課（學校）
10:00 - 完成作業A（學校，deadline: 今天）
12:00 - 午餐
13:00 - 實習工作會議（公司）
14:00 - 完成實習報告（公司，deadline: 明天）
16:00 - 社團活動籌備（社團）
18:00 - 完成作業B（學校，deadline: 後天）
```

**當前系統問題：**
1. ❌ 無法快速切換身份視圖
2. ❌ 無法按身份篩選任務
3. ❌ 衝突檢測只顯示，無法快速解決
4. ❌ 無法看到跨身份的整體時間分配

### 情境 2: 職場人士 - 任務依賴與協作

**用戶背景：**
- 專案經理（公司身份）
- 需要管理多個專案任務

**典型場景：**
```
任務A: 設計UI（依賴：需求分析完成）
任務B: 開發功能（依賴：設計UI完成）
任務C: 測試功能（依賴：開發功能完成）
```

**當前系統問題：**
1. ❌ 任務依賴關係在UI中顯示不清晰
2. ❌ 無法阻止在依賴未完成時開始任務
3. ❌ 完成任務後，依賴任務沒有明顯提示解鎖
4. ❌ 無法查看任務依賴鏈的完整視圖

### 情境 3: 組織管理員 - 任務分配與追蹤

**用戶背景：**
- 組織管理員
- 需要分配任務給成員並追蹤進度

**典型場景：**
```
1. 在組織任務看板創建任務
2. 分配給成員A和成員B
3. 成員A和B應該收到通知
4. 任務自動同步到成員的個人任務中樞
5. 管理員需要看到任務進度
```

**當前系統問題：**
1. ❌ 任務分配通知可能不完整
2. ❌ 無法看到被分配任務的整體進度
3. ❌ 無法批量管理組織任務
4. ❌ 任務完成後沒有自動通知分配者

### 情境 4: 時間管理 - 衝突解決與重新排程

**用戶背景：**
- 忙碌的專業人士
- 需要智能排程和衝突解決

**典型場景：**
```
週一上午：已排程3個任務（共4小時）
週一中午：收到緊急任務（2小時，deadline: 週二）
需要：自動重新排程，解決衝突
```

**當前系統問題：**
1. ❌ 衝突檢測只顯示，無法自動解決
2. ❌ 插入新任務時不會自動重新排程
3. ❌ 無法看到"如果完成這個任務，會影響哪些其他任務"
4. ❌ 無法預覽重新排程的結果

---

## 發現的邏輯問題

### 問題 1: 任務依賴關係未在UI中阻止操作 ⚠️

**問題描述：**
- 任務有依賴關係時，用戶仍然可以標記為"進行中"
- 沒有視覺提示表明任務被阻塞
- 沒有阻止用戶在依賴未完成時開始任務

**影響：**
- 用戶可能誤以為可以開始任務
- 導致任務順序混亂
- 影響專案進度追蹤

**修復方案：**
1. 在 `TaskRow` 中顯示阻塞狀態
2. 在 `TaskDetailView` 中顯示依賴狀態
3. 在任務列表中使用視覺標記（鎖定圖標）
4. 阻止用戶在依賴未完成時標記任務為進行中

### 問題 2: 任務衝突檢測只在顯示時觸發 ⚠️

**問題描述：**
- 衝突檢測只在 `TasksViewModel` 中定期執行
- 創建新任務時沒有即時檢查衝突
- 更新任務時間時沒有即時檢查衝突

**影響：**
- 用戶可能創建衝突的任務而不自知
- 需要手動刷新才能看到衝突
- 無法在創建時就避免衝突

**修復方案：**
1. 在 `AddTaskView` 中即時檢查衝突
2. 在 `EditTaskView` 中即時檢查衝突
3. 在自動排程時檢查並解決衝突
4. 提供衝突解決建議

### 問題 3: 組織任務分配通知可能不完整 ⚠️

**問題描述：**
- Firebase Functions 處理通知，但客戶端可能沒有正確處理
- 用戶可能沒有收到被分配任務的通知
- 無法在APP內看到分配通知歷史

**影響：**
- 用戶可能錯過重要任務
- 協作效率降低
- 任務追蹤困難

**修復方案：**
1. 檢查 Firebase Functions 是否正確配置
2. 在客戶端添加通知處理邏輯
3. 添加APP內通知中心
4. 添加任務分配歷史記錄

### 問題 4: 任務完成後依賴任務沒有明顯提示 ⚠️

**問題描述：**
- 完成任務後，依賴此任務的其他任務沒有明顯提示
- 用戶需要手動檢查哪些任務可以開始了
- 沒有"任務解鎖"的視覺反饋

**影響：**
- 用戶可能不知道可以開始新任務
- 專案進度可能停滯
- 錯過最佳開始時機

**修復方案：**
1. 完成任務時顯示解鎖的任務列表
2. 在任務列表中高亮顯示新解鎖的任務
3. 發送通知告知用戶有新任務可以開始
4. 添加"可開始的任務"篩選器

### 問題 5: 無法按組織/身份篩選任務 ⚠️

**問題描述：**
- 任務列表只能按類別（學校/工作/社團/生活）篩選
- 無法按具體組織篩選
- 無法快速切換身份視圖

**影響：**
- 多身份用戶難以管理任務
- 無法快速查看特定組織的任務
- 跨組織任務管理困難

**修復方案：**
1. 添加組織篩選器
2. 添加身份切換功能
3. 在任務卡片中顯示組織信息
4. 添加"我的組織任務"視圖

---

## 缺失的功能

### 功能 1: 任務依賴關係視覺化 🔴 高優先級

**需求：**
- 甘特圖視圖顯示任務依賴鏈
- 任務依賴關係圖（可視化圖表）
- 依賴鏈路徑顯示

**實現細節：**
1. 創建 `TaskDependencyGraphView`
2. 使用圖形庫（如 SwiftUI Charts）顯示依賴關係
3. 支持縮放和拖拽
4. 點擊任務節點可導航到任務詳情

### 功能 2: 智能衝突解決建議 🟡 中優先級

**需求：**
- 當檢測到衝突時，提供解決建議
- 自動重新排程選項
- 衝突任務的優先級比較

**實現細節：**
1. 擴展 `TaskConflictDetector` 添加建議功能
2. 創建 `ConflictResolutionView`
3. 提供多種解決方案（移動任務、調整時間、取消任務）
4. 預覽重新排程結果

### 功能 3: 任務分配追蹤面板 🟡 中優先級

**需求：**
- 組織管理員可以看到所有分配的任務
- 任務進度追蹤
- 成員工作負載視圖

**實現細節：**
1. 創建 `TaskAssignmentDashboardView`
2. 顯示任務分配統計
3. 成員工作負載圖表
4. 任務完成率追蹤

### 功能 4: 任務完成慶祝與解鎖通知 🟢 低優先級

**需求：**
- 完成任務時的慶祝動畫
- 解鎖任務的通知
- 成就系統

**實現細節：**
1. 擴展現有的 `CelebrationView`
2. 添加解鎖任務的動畫
3. 發送解鎖通知
4. 記錄成就

### 功能 5: 批量任務操作 🟡 中優先級

**需求：**
- 批量標記完成
- 批量刪除
- 批量移動日期
- 批量更改優先級

**實現細節：**
1. 添加任務選擇模式
2. 創建批量操作工具欄
3. 實現批量操作API
4. 添加確認對話框

### 功能 6: 任務模板系統 🟢 低優先級

**需求：**
- 創建任務模板
- 從模板快速創建任務
- 組織任務模板庫

**實現細節：**
1. 創建 `TaskTemplate` 模型
2. 實現模板管理服務
3. 添加模板選擇UI
4. 支持模板參數化

### 功能 7: 時間塊與任務整合 🟡 中優先級

**需求：**
- 時間塊視圖顯示任務
- 任務自動填充時間塊
- 時間塊衝突檢測

**實現細節：**
1. 整合 `TimeBlockService` 和 `TaskService`
2. 創建時間塊視圖
3. 實現任務到時間塊的映射
4. 時間塊衝突檢測

### 功能 8: 任務評論與協作 🟡 中優先級

**需求：**
- 任務評論功能
- @提及成員
- 評論通知

**實現細節：**
1. 擴展 `TaskComment` 模型
2. 實現評論服務
3. 創建評論UI
4. 實現@提及解析

---

## 詳細改進方案

### 改進 1: 任務依賴關係UI增強

#### 1.1 任務卡片阻塞狀態顯示

**文件：** `Views/Tasks/TaskRow.swift`

**修改內容：**
```swift
// 在 TaskRow 中添加阻塞狀態顯示
private var isBlockedIndicator: some View {
    if isBlocked {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.orange)
            Text("等待依賴")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}
```

#### 1.2 任務詳情依賴關係視圖增強

**文件：** `Views/Tasks/TaskDetailView.swift`

**修改內容：**
- 添加依賴關係圖視圖
- 顯示依賴鏈路徑
- 添加"解鎖任務"列表

#### 1.3 阻止在依賴未完成時開始任務

**文件：** `ViewModels/TasksViewModel.swift`

**修改內容：**
```swift
func toggleTaskDoneAsync(task: Task) async -> Bool {
    // 檢查依賴關係
    if !task.isDone {
        let dependencyService = TaskDependencyService()
        let allTasks = todayTasks + weekTasks + backlogTasks
        if !dependencyService.canStartTask(task, allTasks: allTasks) {
            await MainActor.run {
                ToastManager.shared.showToast(
                    message: "無法開始：還有未完成的依賴任務",
                    type: .warning
                )
            }
            return false
        }
    }
    // ... 原有邏輯
}
```

### 改進 2: 即時衝突檢測

#### 2.1 創建任務時檢查衝突

**文件：** `Views/Tasks/AddTaskView.swift`

**修改內容：**
```swift
private func checkConflictsBeforeCreate() async -> Bool {
    guard let plannedDate = plannedDate ?? deadline else {
        return true // 沒有時間，無需檢查
    }
    
    let newTask = Task(
        // ... 任務參數
        plannedDate: plannedDate,
        estimatedMinutes: Int(estimatedHours * 60)
    )
    
    let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
    let conflictDetector = TaskConflictDetector()
    let conflicts = conflictDetector.checkInsertionConflicts(
        newTask: newTask,
        into: allTasks
    )
    
    if !conflicts.isEmpty {
        await MainActor.run {
            showingConflictAlert = true
            detectedConflicts = conflicts
        }
        return false
    }
    
    return true
}
```

#### 2.2 衝突解決對話框

**文件：** `Views/Tasks/ConflictResolutionView.swift` (新建)

**實現內容：**
- 顯示衝突詳情
- 提供解決建議
- 允許用戶選擇解決方案
- 預覽重新排程結果

### 改進 3: 組織任務篩選

#### 3.1 添加組織篩選器

**文件：** `Views/Tasks/TasksView.swift`

**修改內容：**
```swift
@State private var selectedOrganizationId: String? = nil

private var organizationFilter: some View {
    Menu {
        Button {
            selectedOrganizationId = nil
        } label: {
            Label("所有組織", systemImage: "checkmark")
        }
        
        ForEach(viewModel.userOrganizations, id: \.id) { org in
            Button {
                selectedOrganizationId = org.id
            } label: {
                Label(org.name, systemImage: org.id == selectedOrganizationId ? "checkmark" : "")
            }
        }
    } label: {
        HStack {
            Image(systemName: "building.2")
            Text(selectedOrganizationId == nil ? "所有組織" : "已選組織")
        }
    }
}
```

#### 3.2 任務列表按組織篩選

**文件：** `ViewModels/TasksViewModel.swift`

**修改內容：**
```swift
@Published var selectedOrganizationId: String? = nil

var filteredTasks: [Task] {
    var tasks = allTasks
    if let orgId = selectedOrganizationId {
        tasks = tasks.filter { $0.sourceOrgId == orgId }
    }
    return tasks
}
```

### 改進 4: 任務完成解鎖通知

#### 4.1 完成任務時檢查解鎖任務

**文件：** `ViewModels/TasksViewModel.swift`

**修改內容：**
```swift
func toggleTaskDoneAsync(task: Task) async -> Bool {
    let wasDone = task.isDone
    let success = await taskService.toggleTaskDone(task: task)
    
    if success && !wasDone {
        // 檢查解鎖的任務
        let dependencyService = TaskDependencyService()
        let allTasks = todayTasks + weekTasks + backlogTasks
        let unlockedTasks = dependencyService.getUnlockedTasks(
            completedTaskId: task.id ?? "",
            allTasks: allTasks
        )
        
        if !unlockedTasks.isEmpty {
            await MainActor.run {
                showUnlockedTasksNotification(unlockedTasks)
            }
        }
    }
    
    return success
}

private func showUnlockedTasksNotification(_ tasks: [Task]) {
    let taskNames = tasks.prefix(3).map { $0.title }.joined(separator: "、")
    let message = tasks.count > 3 
        ? "\(taskNames) 等 \(tasks.count) 個任務已解鎖！"
        : "\(taskNames) 已解鎖！"
    
    ToastManager.shared.showToast(message: message, type: .success)
    
    // 高亮顯示解鎖的任務
    newlyUnlockedTaskIds = Set(tasks.compactMap { $0.id })
    
    // 3秒後取消高亮
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        newlyUnlockedTaskIds.removeAll()
    }
}
```

#### 4.2 解鎖任務高亮顯示

**文件：** `Views/Tasks/TaskRow.swift`

**修改內容：**
```swift
// 在 TaskRow 中添加高亮效果
.overlay(
    Group {
        if isNewlyUnlocked {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: isNewlyUnlocked)
        }
    }
)
```

### 改進 5: 任務分配通知處理

#### 5.1 APP內通知中心

**文件：** `Views/Notifications/NotificationCenterView.swift` (新建)

**實現內容：**
- 顯示所有通知
- 任務分配通知
- 任務更新通知
- 評論通知
- 標記已讀/未讀

#### 5.2 通知處理服務

**文件：** `Services/NotificationHandlerService.swift` (新建)

**實現內容：**
- 處理推送通知
- 處理APP內通知
- 通知分類
- 通知統計

---

## 實施優先級

### 🔴 高優先級（立即實施）

1. **任務依賴關係UI增強**
   - 阻塞狀態顯示
   - 阻止在依賴未完成時開始任務
   - 預計工作量：4小時

2. **即時衝突檢測**
   - 創建任務時檢查衝突
   - 衝突解決對話框
   - 預計工作量：6小時

3. **組織任務篩選**
   - 組織篩選器
   - 身份切換
   - 預計工作量：3小時

### 🟡 中優先級（近期實施）

4. **任務完成解鎖通知**
   - 解鎖任務檢測
   - 高亮顯示
   - 預計工作量：4小時

5. **任務分配追蹤面板**
   - 分配統計
   - 進度追蹤
   - 預計工作量：8小時

6. **批量任務操作**
   - 選擇模式
   - 批量操作
   - 預計工作量：6小時

### 🟢 低優先級（未來實施）

7. **任務依賴關係視覺化**
   - 甘特圖
   - 依賴圖
   - 預計工作量：12小時

8. **任務模板系統**
   - 模板管理
   - 快速創建
   - 預計工作量：8小時

---

## 實施計劃

### 階段 1: 核心邏輯修復（第1週）

**目標：** 修復所有邏輯問題，確保基本功能正常

**任務：**
1. ✅ 任務依賴關係UI增強
2. ✅ 即時衝突檢測
3. ✅ 組織任務篩選
4. ✅ 任務完成解鎖通知

### 階段 2: 功能增強（第2週）

**目標：** 添加缺失的核心功能

**任務：**
1. ✅ 任務分配追蹤面板
2. ✅ 批量任務操作
3. ✅ APP內通知中心

### 階段 3: 進階功能（第3週）

**目標：** 添加進階功能和視覺化

**任務：**
1. ✅ 任務依賴關係視覺化
2. ✅ 智能衝突解決建議
3. ✅ 時間塊與任務整合

---

## 總結

本次分析發現了 **5個邏輯問題** 和 **8個缺失功能**。優先修復邏輯問題，然後逐步添加缺失功能。所有改進都將提升用戶體驗和系統可靠性。

