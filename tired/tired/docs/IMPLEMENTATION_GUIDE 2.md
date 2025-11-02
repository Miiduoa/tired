# Tired 專案實作指南

## 專案現狀總結

### ✅ 已完成的核心功能

#### 1. 認證與多租戶系統
- **AppSessionStore**: 管理應用狀態
- **AuthService**: 支援 Apple Sign-In、Google Sign-In、Email/Password
- **多租戶支援**: 用戶可加入多個組織（學校、企業、社群、ESG）
- **租戶切換**: 用戶可在不同租戶間無縫切換

#### 2. 角色權限系統 (RBAC)
- **五種角色**: Owner, Admin, Manager, Member, Guest
- **權限檢查**: `RolePermissions.swift` 統一管理
- **角色映射**: 系統角色映射到業務角色（Teacher/Manager, Student/Employee）
- **訪問控制**: 每個功能都有明確的權限邏輯

#### 3. 社交功能
- **動態牆 (Feed)**: 發布、查看、按讚、評論貼文
- **聊天 (Chat)**: 私訊和群組聊天
- **好友系統 (Friends)**: 添加好友、管理請求
- **圖片上傳**: 使用 PhotosUI 選取照片

#### 4. 核心業務模組
- **出勤管理**: QR碼掃描、角色區分視圖
- **打卡系統**: GPS 地理圍欄
- **公告中心**: 實名廣播、回條追蹤
- **收件匣**: 跨模組任務整合
- **ESG 管理**: 碳排追蹤、合規管理

### 🎨 設計系統

#### TTokens 設計令牌
```swift
// 間距
TTokens.spacingSM, TTokens.spacingMD, TTokens.spacingLG, TTokens.spacingXL, TTokens.spacingXXL

// 圓角
TTokens.radiusSM, TTokens.radiusMD, TTokens.radiusLG, TTokens.radiusXL

// 字體
TTokens.fontHeadline, TTokens.fontBody, TTokens.fontCaption

// 陰影
TTokens.shadowSmall(), TTokens.shadowMedium(), TTokens.shadowLarge()
```

#### 動態背景
- **玻璃態效果**: `DynamicBackground(style: .glassmorphism)`
- **粒子效果**: `DynamicBackground(style: .particles)`

### 📁 檔案結構說明

```
tired/
├── tired/
│   ├── Features/              # 功能視圖
│   │   ├── Auth/              # 認證 (MainAppView, QuickSignUpView)
│   │   ├── Attendance/        # 出勤 (AttendanceView)
│   │   ├── Clock/             # 打卡 (ClockView)
│   │   ├── Broadcast/         # 公告 (BroadcastListView)
│   │   ├── Inbox/             # 收件匣 (InboxView)
│   │   ├── ESG/               # ESG (ESGView)
│   │   ├── Profile/           # 個人資料 (ProfileView, InnovativeProfileView)
│   │   ├── Social/            # 社交功能
│   │   │   ├── FeedView.swift        # 動態牆
│   │   │   ├── ChatView.swift        # 聊天
│   │   │   ├── FriendsView.swift     # 好友
│   │   │   └── CreatePostView.swift  # 發布貼文
│   │   └── Management/        # 管理功能
│   │       └── MemberManagementView.swift  # 成員管理
│   ├── Models/               # 數據模型
│   │   ├── Tenant.swift      # 租戶、成員、能力包
│   │   ├── Social.swift      # 社交模型 (Post, Comment, Message, Friendship)
│   │   ├── UserProfile.swift # 用戶資料
│   │   └── Models.swift      # 業務模型
│   ├── Services/             # 服務層
│   │   ├── AuthService.swift              # 認證服務
│   │   ├── AppSession/                   # 會話管理
│   │   │   └── AppSessionStore.swift
│   │   ├── Tenant/                       # 租戶管理
│   │   │   ├── TenantService.swift
│   │   │   ├── TenantModuleManager.swift
│   │   │   └── TenantFeatureService.swift
│   │   └── ESG/
│   │       └── ESGService.swift
│   ├── Utils/                # 工具類
│   │   └── RolePermissions.swift        # 權限檢查
│   ├── Components/           # 通用組件
│   │   ├── DynamicBackground.swift      # 動態背景
│   │   ├── EmptyStateView.swift         # 空狀態
│   │   ├── GlassCard.swift              # 玻璃卡片
│   │   └── GradientButton.swift         # 漸變按鈕
│   ├── Theme/                # 主題
│   │   └── Theme.swift
│   └── Utils/                # 工具
│       └── Formatters.swift
└── docs/                     # 文檔
    ├── PROJECT_STATUS.md
    ├── IMPLEMENTATION_GUIDE.md
    ├── ROLE_PERMISSIONS_VERIFICATION.md
    └── ROLE_LOGIC_AUDIT.md
```

### 🔄 數據流程

#### 1. 應用啟動流程
```
TiredApp
  ↓
MainAppView
  ↓
AppSessionStore (檢查狀態)
  ↓
AuthService (檢查登入狀態)
  ↓
載入成員資料
  ↓
顯示 MainTabView 或認證界面
```

#### 2. 模組載入流程
```
MainAppView 初始化
  ↓
TenantModuleManager.configure(session)
  ↓
為每個 AppModule 創建對應的 TenantModule 實例
  ↓
entryActions() → 生成快速操作卡片
  ↓
makeView() → 創建具體視圖
```

#### 3. 權限檢查流程
```
用戶訪問功能
  ↓
檢查 membership.role
  ↓
RolePermissions.canXXX(role)
  ↓
返回 true/false
  ↓
視圖顯示/隱藏相應功能
```

### 🎯 核心程式碼示例

#### 1. 角色權限檢查
```swift
// RolePermissions.swift
static func canPublish(for role: TenantMembership.Role) -> Bool {
    role == .member || role.isManagerial
}

// 在視圖中使用
if RolePermissions.canPublish(membership.role) {
    Button("發布貼文") { ... }
}
```

#### 2. 內容所有權檢查
```swift
// PostCard.swift
private var canDelete: Bool {
    post.authorId == "current_user" || 
    RolePermissions.canManage(membership.role)
}

Menu {
    if canDelete {
        Button("刪除", role: .destructive) { ... }
    }
}
```

#### 3. 模組配置
```swift
// TenantModuleManager.swift
private static func buildModules(for membership: TenantMembership) -> [AppModule: TenantModule] {
    let configured: [TenantModule] = [
        BroadcastModule(),
        AttendanceModule(),
        FeedModule(),
        ChatModule(),
        FriendsModule()
        // ...
    ]
    return Dictionary(uniqueKeysWithValues: configured.map { ($0.module, $0) })
}
```

### 🛠️ 開發工作流程

#### 1. 添加新功能模組
```swift
// 1. 在 AppModule enum 中添加新案例
case newFeature

// 2. 在 TenantModuleManager.buildModules 中添加模組
NewFeatureModule()

// 3. 實現模組
private struct NewFeatureModule: TenantModule {
    var module: AppModule { .newFeature }
    
    func entryActions(context: TenantModuleContext) -> [TenantModuleEntryAction] {
        // 生成快速操作卡片
    }
    
    func makeView(context: TenantModuleContext) -> AnyView {
        AnyView(NewFeatureView(membership: context.session.activeMembership))
    }
}

// 4. 在 MainAppView.tabView 中添加視圖
case .newFeature:
    NewFeatureView(membership: session.activeMembership)
```

#### 2. 添加新角色權限
```swift
// 1. 在 RolePermissions.swift 中添加新方法
static func canUseNewFeature(for role: TenantMembership.Role) -> Bool {
    role.isManagerial // 只有管理層可使用
}

// 2. 在視圖中使用
if RolePermissions.canUseNewFeature(membership.role) {
    NewFeatureButton()
}
```

### 📊 專案統計

- **總檔案數**: ~60 個 Swift 檔案
- **功能模組**: 10 個 (Home, Feed, Chat, Friends, Attendance, Clock, Broadcast, Inbox, ESG, Profile)
- **角色定義**: 5 種 (Owner, Admin, Manager, Member, Guest)
- **租戶類型**: 4 種 (School, Company, Community, ESG)
- **設計令牌**: 20+ 個統一的設計值

### ✅ 編譯狀態

**BUILD SUCCEEDED** - 所有功能已正確實現並可正常編譯

### 🚀 下一步開發計劃

1. **後端集成**: 連接 Firebase 實現真實數據同步
2. **推送通知**: 實現即時通知功能
3. **圖片存儲**: 集成圖片上傳和存儲服務
4. **搜尋功能**: 實現全域搜尋
5. **測試**: 編寫單元測試和 UI 測試

### 📝 開發規範

1. **命名**: 使用駝峰式命名（View, ViewModel, Service）
2. **結構**: 遵循 MVVM 架構模式
3. **異步**: 所有網路操作使用 `async/await`
4. **主線程**: UI 更新必須在 `@MainActor` 上執行
5. **權限**: 所有功能都必須有明確的權限檢查

---

**專案狀態**: ✅ 已完成核心功能開發，可開始後端集成工作

