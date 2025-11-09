# Tired - 大學生任務中樞

一個專為大學生設計的任務管理 App，幫助你管理學校、工作和個人任務，並自動生成可驗證的經歷線。

## 功能特色

### Phase 0.0a 已實現

✅ **Today / This Week / Backlog 視圖**
- Today 四區邏輯：截止逾期、今天到期、工作日延後、今天清單
- This Week 週壓力總覽和每日任務管理
- Backlog 任務過濾和批次操作

✅ **現代化 UI（iOS 玻璃效果）**
- 毛玻璃背景效果（Material）
- 漸變邊框和陰影
- 流暢動畫過渡

✅ **Onboarding 流程**
- 學生狀態選擇
- 學期設定
- 容量配置

✅ **任務管理核心功能**
- 快速新增任務
- 焦點任務（最多 5 個）
- 任務分類（學校/工作/個人/其他）
- 優先度管理（P0-P3）
- 日期鎖定（手動排程）

✅ **日期系統**
- 時區處理
- 反范式日期欄位（Firestore 查詢優化）
- 日期工具函數庫

✅ **專注模式基礎**
- FocusState 狀態管理
- 崩潰恢復機制（localStorage）

✅ **輕量 Undo 系統**
- 10 秒內復原
- 支援完成/跳過/批次操作

✅ **經歷線基礎**
- 任務證據（Evidence）
- 工作會話（WorkSession）
- Streak 連續完成天數

✅ **Firebase 整合**
- Firestore security rules
- Firestore indexes
- 認證系統（Email/Apple/Google）

## 技術架構

### 數據模型
- `Task` - 任務（包含證據、工作會話、依賴關係）
- `Event` - 事件（課程、會議等）
- `Course` - 課程
- `TermConfig` - 學期配置
- `UserProfile` - 用戶檔案
- `UserDailyLog` - 每日日誌

### 服務層
- `TaskService` - 任務管理核心服務
- `AuthService` - 認證服務
- `FirebaseService` - Firebase 配置
- `FocusState` - 專注模式狀態管理
- `UndoService` - 撤銷服務
- `AppSession` - 應用會話管理

### UI 層
- 玻璃效果主題系統（AppTheme）
- 可重用組件（GlassCard, FloatingActionButton）
- 主要視圖（Today, ThisWeek, Backlog, Me, Onboarding）

## 開始使用

### 前置需求
- Xcode 15+
- iOS 16.0+
- Firebase 項目

### Firebase 配置

1. 在 Firebase Console 創建新項目
2. 下載 `GoogleService-Info.plist` 並放到項目根目錄
3. 部署 Firestore rules：

```bash
firebase deploy --only firestore:rules
```

4. 部署 Firestore indexes：

```bash
firebase deploy --only firestore:indexes
```

### 建置運行

1. 打開 Xcode：
```bash
open tired.xcodeproj
```

2. 選擇模擬器或真機
3. 按 Cmd+R 運行

## 項目結構

```
tired/
├── Models/              # 數據模型
│   ├── Task.swift
│   ├── Event.swift
│   ├── Course.swift
│   └── ...
├── Services/            # 服務層
│   ├── TaskService.swift
│   ├── AuthService.swift
│   └── ...
├── Utils/               # 工具類
│   ├── DateUtils.swift
│   ├── AppSession.swift
│   ├── UndoService.swift
│   └── FocusState.swift
├── Views/               # 視圖層
│   ├── Today/
│   ├── ThisWeek/
│   ├── Backlog/
│   ├── Me/
│   └── Onboarding/
├── Components/          # 可重用組件
│   └── GlassCard.swift
├── Theme/               # 主題系統
│   └── AppTheme.swift
└── tiredApp.swift       # 主 App 入口
```

## 核心概念

### S_term_TW_open（學期過濾）

所有「Today / This Week / autoplan / 通知 / 卡片」都使用統一的過濾邏輯：
- state = 'open'
- deleted_at IS NULL
- 非學校類別 OR (學校類別 AND (當前學期 OR 跨學期重要))

### 四區邏輯（Today 視圖）

1. **截止逾期** - deadline_date < today
2. **今天到期** - deadline_date = today
3. **工作日延後** - planned_work_date < today
4. **今天清單** - planned_work_date = today

### 日期鎖定（is_date_locked）

設為 true 的時機：
- This Week 拖拉任務
- Task 詳細頁手動選日期
- Today 卡片「排今天」

不設為 true：
- autoplan 排程結果
- 系統輔助排程

## 待實現功能（Phase 0.0a+）

⏳ **專注模式完整實現**
- Pomodoro 計時器
- 休息提醒
- 統計報表

⏳ **卡片系統**
- 學期切換整理卡
- Gap 回鍋卡
- 當日壓力調整卡
- Closing Card
- Weekly Review Card

⏳ **Autoplan**
- 週排程算法
- 依賴關係處理
- 容量計算

⏳ **考試準備模式**
- 任務拆分
- 複習排程

⏳ **經歷匯出**
- 本學期完成任務整理
- 包含證據和 daily highlights

## 開發規範

### 日期處理
所有日期計算必須使用 `DateUtils`，不可直接使用 Date() 計算。

### 任務操作
所有任務狀態變更應通過 `TaskService`，並記錄 Undo 操作。

### 玻璃效果
使用 `.glassCard()`, `.glassBackground()` 等 View modifier 保持一致的視覺風格。

### 優先度
- P0 - 緊急
- P1 - 重要
- P2 - 一般
- P3 - 低優先

### 分類
- school - 學校（需要 term_id）
- work - 工作
- personal - 個人
- other - 其他

## License

MIT License

## 作者

Tired Team
