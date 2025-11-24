# 待辦事項列表

- [ ] 在 EditTaskView.swift 新增任務負責人、任務依賴、提醒時間及標籤管理 UI
- [ ] 在 TasksViewModel.swift 新增欄位邏輯處理，支援任務的負責人、依賴、提醒等資料的讀寫與權限驗證
- [ ] 在 TaskDetailView.swift 與 AddTaskView.swift 同步新增及顯示新的任務欄位，完善使用者交互
- [ ] 在 TasksView.swift 補足搜尋結果可點擊跳轉任務詳細頁面功能，完善按鍵回饋
- [ ] 統一全專案的介面文字為繁體中文
- [ ] 補齊所有按鍵綁定事件並優化相應反饋條件
- [ ] 全專案代碼優化與除錯，確保既有與新增功能穩定可靠

# 開發順序

1. 先修改 EditTaskView.swift 的 UI 及資料綁定
2. 修改 TasksViewModel.swift，支援新增欄位的后端邏輯
3. 修改 TaskDetailView.swift 與 AddTaskView.swift，完善 UI 範圍
4. 修改 TasksView.swift，補齊交互及搜尋跳轉
5. 全局測試、優化錯誤修正

# 目的

- 強化任務協作能力，補足多人與複雜任務管理需求
- 提升使用者體驗與操作流暢性
- 保持中文簡潔明瞭、一致性及易用性
