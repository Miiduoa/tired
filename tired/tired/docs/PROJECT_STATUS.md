# Tired 專案開發狀態

## 專案概述

Tired 是一個多租戶社交辦公平台，支持校園、企業、社群和 SME-ESG 四種租戶類型，提供出勤、打卡、公告、ESG 和社交等完整功能。

## 已實現的核心功能

### 1. 角色權限系統 ✅

#### 角色定義
- **Owner**（擁有者）：完全控制權限
- **Admin**（管理員）：可以管理成員和功能
- **Manager**（經理）：可以管理部門/班級
- **Member**（成員）：基本功能使用
- **Guest**（訪客）：僅能查看

#### 權限檢查
- 創建了 `RolePermissions.swift` 統一管理所有權限檢查
- 所有功能都有正確的角色權限邏輯
- 社交功能限制訪客訪問
- 內容所有權檢查（僅作者或管理員可刪除）

### 2. 社交功能 ✅

#### 動態牆 (Feed)
- **位置**: `tired/tired/Features/Social/FeedView.swift`
- **功能**: 查看和發布動態、按讚、評論、分享
- **權限**: 
  - 所有用戶可查看
  - 僅成員以上可發布
  - 內容所有者或管理員可刪除

#### 聊天 (Chat)
- **位置**: `tired/tired/Features/Social/ChatView.swift`
- **功能**: 私訊、群組聊天
- **權限**: 僅成員以上可發送訊息
- **支援**: 文字、圖片、系統訊息

#### 好友 (Friends)
- **位置**: `tired/tired/Features/Social/FriendsView.swift`
- **功能**: 添加好友、管理好友請求、查看推薦好友
- **權限**: 僅成員以上可使用

### 3. 核心業務模組 ✅

#### 出勤管理 (Attendance)
- **位置**: `tired/tired/Features/Attendance/AttendanceView.swift`
- **功能**: 
  - QR 碼掃描點名
  - 管理者和成員不同視圖
  - 角色映射：Teacher ↔ Manager, Student ↔ Employee

#### 打卡 (Clock)
- **位置**: `tired/tired/Features/Clock/ClockView.swift`
- **功能**: GPS 地理圍欄、外勤管理、異常追蹤

#### 公告 (Broadcast)
- **位置**: `tired/tired/Features/Broadcast/BroadcastListView.swift`
- **功能**: 實名廣播、回條追蹤

#### 收件匣 (Inbox)
- **位置**: `tired/tired/Features/Inbox/InboxView.swift`
- **功能**: 跨模組任務整合、優先級管理

#### ESG
- **位置**: `tired/tired/Features/ESG/ESGView.swift`
- **功能**: 碳排追蹤、帳單 OCR、合規管理

### 4. 成員管理 ✅

#### 成員管理界面
- **位置**: `tired/tired/Features/Management/MemberManagementView.swift`
- **功能**: 
  - 僅 Owner 和 Admin 可訪問
  - 成員統計
  - 角色調整
  - 邀請新成員

### 5. 架構設計 ✅

#### 模組管理
- **TenantModuleManager**: 管理所有功能模組
- **每個模組實現**: `entryActions` 和 `makeView`
- **統一的 Tab 和 Entry 邏輯**

#### 數據模型
- **Tenant.swift**: 租戶、成員、能力包定義
- **Social.swift**: 社交功能數據模型
- **Models.swift**: 業務數據模型

## 技術架構

### MVVM 模式
所有視圖遵循 MVVM：
- View: SwiftUI 視圖
- ViewModel: `ObservableObject` 管理狀態
- Model: Codable 數據模型

### 異步處理
- 使用 `async/await`
- `@MainActor` 確保 UI 更新在主線程

### 設計系統
- **TTokens**: 統一的設計令牌（間距、圓角、字體、陰影）
- **DynamicBackground**: 玻璃態和粒子背景效果

## 資料流

### 1. 認證流程
```
AppSessionStore (狀態管理)
  ↓
AuthService (認證服務)
  ↓
User 認證成功
  ↓
載入 TenantMemberships
  ↓
切換到 AppSession (ready)
```

### 2. 模組載入流程
```
TenantModuleManager.configure()
  ↓
根據 membership 構建模組映射
  ↓
entryActions() → 生成快速操作卡片
  ↓
makeView() → 創建視圖
```

### 3. 權限檢查流程
```
RolePermissions.canXXX(role)
  ↓
檢查角色權限
  ↓
返回布爾值
  ↓
View 根據權限顯示/隱藏
```

## 待完善功能

### 1. 後端集成 🔄
- [ ] 所有 TODO 標記的 API 調用
- [ ] Firebase/真實後端連接
- [ ] 實時同步數據

### 2. 進階功能 📋
- [ ] 推播通知
- [ ] 檔案上傳/下載
- [ ] 圖片編輯
- [ ] 搜尋功能
- [ ] 深色模式完整支援

### 3. 測試 🧪
- [ ] 單元測試
- [ ] UI 測試
- [ ] 集成測試

## 文件結構

```
tired/
├── tired/
│   ├── Features/
│   │   ├── Auth/              # 認證相關
│   │   ├── Attendance/        # 出勤管理
│   │   ├── Clock/             # 打卡
│   │   ├── Broadcast/         # 公告
│   │   ├── Inbox/             # 收件匣
│   │   ├── ESG/               # ESG 管理
│   │   ├── Profile/           # 個人資料
│   │   ├── Social/            # 社交功能
│   │   │   ├── FeedView.swift
│   │   │   ├── ChatView.swift
│   │   │   ├── FriendsView.swift
│   │   │   └── CreatePostView.swift
│   │   └── Management/        # 管理功能
│   │       └── MemberManagementView.swift
│   ├── Models/
│   │   ├── Tenant.swift       # 租戶模型
│   │   ├── Social.swift       # 社交模型
│   │   └── Models.swift       # 業務模型
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── AppSession/
│   │   │   └── AppSessionStore.swift
│   │   ├── Tenant/
│   │   │   ├── TenantService.swift
│   │   │   ├── TenantModuleManager.swift
│   │   │   └── TenantFeatureService.swift
│   │   └── Social/
│   │       └── SocialService.swift
│   └── Utils/
│       └── RolePermissions.swift
├── docs/
│   ├── ROLE_PERMISSIONS_VERIFICATION.md
│   ├── ROLE_LOGIC_AUDIT.md
│   └── PROJECT_STATUS.md (本文件)
└── ...
```

## 角色權限矩陣

| 功能模組 | Owner | Admin | Manager | Member | Guest |
|---------|-------|-------|---------|--------|-------|
| 動態牆查看 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 動態牆發布 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 聊天 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 好友管理 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 出勤查看 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 出勤管理 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 公告查看 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 公告發布 | ✅ | ✅ | ❌ | ❌ | ❌ |
| 成員管理 | ✅ | ✅ | ❌ | ❌ | ❌ |

## 下一步開發計劃

### Phase 1: 核心功能完善
1. 完善所有視圖的業務邏輯
2. 實現圖片上傳功能
3. 完善搜尋功能

### Phase 2: 後端集成
1. 連接 Firebase
2. 實現實時數據同步
3. 添加推送通知

### Phase 3: 測試與優化
1. 編寫測試用例
2. 性能優化
3. UI/UX 改進

## 當前編譯狀態

✅ **BUILD SUCCEEDED** - 所有功能已實現並可編譯通過

## 開發原則

1. **角色驅動**: 所有功能都有明確的角色權限
2. **模組化設計**: 每個功能都是獨立的模組
3. **統一設計**: 使用 TTokens 統一設計系統
4. **異步優先**: 所有網路操作都是異步的
5. **MVVM 架構**: 清晰的視圖與邏輯分離

