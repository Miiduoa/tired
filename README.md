# Tired - 多身份任务管理系统

一个专为现代斜杠青年设计的iOS任务管理应用，支持多身份（学生、员工、社团成员等）的任务统筹与智能排程。

## 📱 核心功能

### 1. 多身份管理
- **组织系统**：学校、系所、公司、社团、专案等多种组织类型
- **身份切换**：在不同身份间无缝切换，聚焦当前角色
- **任务分类**：自动按身份分类任务（学校、工作、社团、生活）

### 2. 智能任务中枢
- **今天视图**：显示今日待办，快速查看当天任务
- **本周视图**：周历展示，每日工时预估，直观掌握一周安排
- **未排程列表**：Backlog管理，待排程任务一目了然

### 3. 自动排程（AutoPlan）
- 根据任务优先级、截止日期自动分配到本周各天
- 考虑每日时间容量，避免过载
- 尊重手动锁定的任务日期

### 4. 社群功能（规划中）
- 组织动态墙：查看所属组织的公告和活动
- 活动报名：自动生成参与任务
- 互动功能：点赞、评论

## 🏗️ 技术架构

### 前端
- **框架**：SwiftUI + Combine
- **架构**：MVVM
- **最低版本**：iOS 17+

### 后端
- **数据库**：Firebase Firestore
- **认证**：Firebase Authentication
- **存储**：Firebase Storage（头像、图片）

## 📦 项目结构

> 目前只保留一套 Xcode App 專案，所有程式碼都在 `tired/tired/tired/` 底下。

```
tired/
├── tired.xcodeproj              # Xcode iOS App 專案
└── tired/
    └── tired/                   # App 原始碼根目錄
        ├── tiredApp.swift       # App 入口（@main）
        ├── GoogleService-Info.plist
        ├── Models/              # 数据模型
        ├── Services/            # Firebase / 業務邏輯
        ├── ViewModels/          # 視圖模型
        ├── Views/               # SwiftUI 介面
        └── Utils/               # 工具類（日期、顏色、自動排程）
```

## 🚀 快速开始

### 前置要求

- macOS 14.0+
- Xcode 15.0+
- CocoaPods 或 Swift Package Manager
- Firebase 项目（见下方配置）

### 1. 克隆项目

```bash
git clone <your-repo-url>
cd tired
```

### 2. Firebase 配置

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 创建新项目或使用现有项目
3. 添加 iOS 应用
   - Bundle ID: `com.yourteam.tired`（可自定义）
4. 下载 `GoogleService-Info.plist`
5. 将文件放到 `tired/tired/tired/` 目录下

### 3. 在 Xcode 中打开项目

1. 打开 Xcode  
2. 使用 `File → Open...` 打开 `tired/tired.xcodeproj`  
3. 左上角 Scheme 选擇 `tired`，装置選一台模擬器（例如 iPhone 15 Pro）

### 4. Firestore 数据库配置

在 Firebase Console 中：

1. 进入 Firestore Database
2. 创建数据库（测试模式或生产模式）
3. 设置安全规则（见 `docs/FIRESTORE_RULES.md`）

### 5. 运行应用

1. 在 Xcode 中选择模拟器或真机
2. 点击 Run（⌘R）

## 📊 数据库 Schema

### 核心 Collections

#### users
```typescript
{
  id: string              // 等同于 Auth UID
  name: string
  email: string
  avatarUrl?: string
  timezone?: string
  weeklyCapacityMinutes?: number
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### organizations
```typescript
{
  id: string
  name: string
  type: 'school' | 'department' | 'club' | 'company' | 'project' | 'other'
  description?: string
  avatarUrl?: string
  coverUrl?: string
  isVerified: boolean
  createdByUserId: string
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### memberships （多身份的核心）
```typescript
{
  id: string
  userId: string                    // 指向 users
  organizationId: string            // 指向 organizations
  role: 'owner' | 'admin' | 'staff' | 'student' | 'member'
  title?: string                    // "大二资管系"、"晚班工读生"
  isPrimaryForType?: boolean
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### tasks （核心任务模型）
```typescript
{
  id: string
  userId: string

  // 任务来源
  sourceOrgId?: string              // 来自哪个组织
  sourceAppInstanceId?: string      // 来自哪个小应用
  sourceType: 'manual' | 'org_task' | 'event_signup'

  // 基本信息
  title: string
  description?: string

  // 分类
  category: 'school' | 'work' | 'club' | 'personal'
  priority: 'low' | 'medium' | 'high'

  // 时间
  deadlineAt?: timestamp
  estimatedMinutes?: number

  // 排程
  plannedDate?: timestamp           // 排到哪一天
  isDateLocked: boolean            // 是否锁定（不允许autoplan改动）

  // 状态
  isDone: boolean
  doneAt?: timestamp

  createdAt: timestamp
  updatedAt: timestamp
}
```

完整 Schema 请参考 `docs/DATABASE_SCHEMA.md`

## 🎯 使用场景示例

### 典型的一天

**早上 8:00 - 学生身份**
- 打开 App → Today 页面
- 查看今日课表和作业
- 标记"数据库作业"预估2小时

**下午 15:00 - 社团成员**
- 切换到"社团"身份筛选
- 看到吉他社周五活动
- 点击"报名" → 自动生成任务

**晚上 18:00 - 员工身份**
- 切换到"工作"身份
- 看到店长排的晚班（18:00-22:00）
- 任务已锁定日期，不会被autoplan移动

**睡前 22:30 - 总览**
- 打开 This Week
- 查看本周每日预估工时
- 点击"自动排程"
- 系统将"期中考复习6小时"拆分到4天

## 🔮 后续开发计划

- [ ] 组织小应用系统（TaskBoard、EventSignup）
- [ ] 完整的动态墙功能
- [ ] 活动报名与签到
- [ ] 通知系统
- [ ] 日历集成
- [ ] 数据统计与可视化
- [ ] iPad 适配
- [ ] macOS 版本（Catalyst）

## 📝 开发文档

- [数据库详细设计](docs/DATABASE_SCHEMA.md)
- [Firestore 安全规则](docs/FIRESTORE_RULES.md)
- [API 文档](docs/API.md)
- [组件设计规范](docs/COMPONENTS.md)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 👥 作者

开发者：[Your Name]

---

**Tired** - 让多重身份的你，不再累 💪
