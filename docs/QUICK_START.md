# Tired App - 快速开始指南

本指南将帮助你在 30 分钟内完成 Tired App 的配置和运行。

## ✅ 检查清单

- [ ] macOS 14.0+ 系统
- [ ] Xcode 15.0+ 已安装
- [ ] 有 Google 账号（用于 Firebase）
- [ ] Apple Developer 账号（真机测试需要，模拟器不需要）

## 📋 步骤 1：克隆项目

```bash
git clone <your-repo-url>
cd tired
```

## 🔥 步骤 2：配置 Firebase（重要！）

### 2.1 创建 Firebase 项目

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 点击"添加项目"
3. 项目名称：`tired-app`（或任意名称）
4. 可选择是否启用 Google Analytics
5. 等待项目创建完成

### 2.2 添加 iOS 应用

1. 在 Firebase 项目概览页，点击 iOS 图标
2. 填写信息：
   - **Apple Bundle ID**: `com.yourteam.tired`
     > 💡 建议使用自己的团队名称，例如 `com.johnsmith.tired`
   - **App 昵称**：Tired（可选）
   - **App Store ID**：留空（可选）

3. 点击"注册应用"

### 2.3 下载配置文件

1. 下载 `GoogleService-Info.plist` 文件
2. **重要**：将此文件移动到项目的 `TiredApp/` 目录下

   ```bash
   # 从下载目录移动到项目
   mv ~/Downloads/GoogleService-Info.plist ./TiredApp/
   ```

### 2.4 启用 Firebase 服务

在 Firebase Console 中：

#### Authentication（认证）
1. 左侧菜单 → Build → Authentication
2. 点击"Get started"
3. 启用登录方式：
   - **Email/Password** ✅ 启用

#### Firestore Database（数据库）
1. 左侧菜单 → Build → Firestore Database
2. 点击"创建数据库"
3. 选择模式：
   - **生产模式**（推荐，需要配置规则）
   - 或**测试模式**（30天后自动关闭写入，适合快速测试）

4. 选择位置：
   - 推荐：`asia-east1`（台湾）或 `asia-northeast1`（日本）

5. 创建完成后，设置安全规则：
   - 点击"规则"标签
   - 复制 [`docs/FIRESTORE_RULES.md`](./FIRESTORE_RULES.md) 中的规则
   - 粘贴并发布

#### Storage（存储）
1. 左侧菜单 → Build → Storage
2. 点击"Get started"
3. 选择位置（与 Firestore 相同）
4. 启用即可

## 🔨 步骤 3：在 Xcode 中创建项目

由于本项目在 Linux 环境创建，需要在 macOS 上创建 Xcode 项目：

### 方式 A：创建新 Xcode 项目（推荐）

1. 打开 Xcode
2. File → New → Project
3. 选择模板：
   - 平台：iOS
   - 模板：**App**
4. 填写信息：
   - Product Name: `TiredApp`
   - Team: 选择你的开发团队
   - Organization Identifier: `com.yourteam`（与 Firebase 中的 Bundle ID 对应）
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ⚠️ 取消勾选 "Use Core Data"、"Include Tests"
5. 选择保存位置（临时位置即可）

6. **替换项目文件**：
   ```bash
   # 删除自动生成的文件（保留 .xcodeproj）
   rm -rf <新项目路径>/TiredApp/*

   # 复制本项目的源文件
   cp -r ./TiredApp/* <新项目路径>/TiredApp/

   # 复制 GoogleService-Info.plist
   cp ./TiredApp/GoogleService-Info.plist <新项目路径>/TiredApp/
   ```

7. 在 Xcode 中刷新项目（右键项目 → Add Files to "TiredApp"）

### 方式 B：手动添加所有文件

1. 创建空白 iOS App 项目（同上）
2. 在 Xcode 左侧项目导航器中：
3. 右键 `TiredApp` 文件夹 → Add Files to "TiredApp"
4. 选择本项目中的所有 Swift 文件和子文件夹
5. 确保勾选 "Copy items if needed"

## 📦 步骤 4：添加 Firebase SDK

### 使用 Swift Package Manager（推荐）

1. 在 Xcode 中，File → Add Package Dependencies
2. 输入 URL：
   ```
   https://github.com/firebase/firebase-ios-sdk.git
   ```
3. 版本选择：**Up to Next Major Version** `10.19.0`
4. 点击 "Add Package"
5. 选择需要的产品（全部勾选）：
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseStorage
6. 点击 "Add Package"

### 或使用 CocoaPods

如果你偏好 CocoaPods：

```bash
# 在项目根目录创建 Podfile
cat > Podfile << EOF
platform :ios, '17.0'
use_frameworks!

target 'TiredApp' do
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
end
EOF

# 安装依赖
pod install

# 之后使用 .xcworkspace 打开项目
open TiredApp.xcworkspace
```

## 🔧 步骤 5：配置 Info.plist

在 Xcode 中：

1. 选择项目根节点 → `TiredApp` target → Info 标签
2. 确认 `GoogleService-Info.plist` 已包含在 Bundle Resources 中

（通常 Xcode 会自动识别）

## ▶️ 步骤 6：运行应用

1. 在 Xcode 顶部选择模拟器：
   - 推荐：**iPhone 15 Pro** 或 **iPhone 15**

2. 点击 Run 按钮（▶️）或按 `⌘R`

3. 首次编译需要 2-5 分钟（下载依赖）

4. 应用启动后，你会看到登录界面

## 🧪 步骤 7：测试应用

### 注册第一个用户

1. 在登录界面点击"没有账号？注册"
2. 填写信息：
   - 姓名：`测试用户`
   - 邮箱：`test@example.com`
   - 密码：至少 6 位，例如 `123456`
3. 点击"注册"

### 创建第一个任务

1. 注册成功后自动登录
2. 进入"任务"标签
3. 点击左下角"+ 新增任务"
4. 填写：
   - 标题：`完成数据库作业`
   - 分类：`学校`
   - 预估时长：`2 小时`
   - 截止日期：明天
5. 点击"完成"
6. 任务会出现在"未排程"列表

### 测试自动排程

1. 切换到"本周"标签
2. 点击右下角"自动排程"
3. 未排程的任务会被分配到本周各天

## 🎨 界面预览

启动后你会看到：

- **登录界面**：简洁的邮箱密码登录
- **任务中枢**：
  - 今天：显示今日任务
  - 本周：按日期分组的周视图
  - 未排程：待安排的任务 Backlog
- **动态墙**：组织和个人动态（占位）
- **身份**：管理你的多个身份（占位）
- **我的**：个人设置和登出

## 🐛 常见问题

### Q1: 编译错误 "No such module 'FirebaseFirestore'"

**原因**：Firebase SDK 未正确安装

**解决**：
1. File → Packages → Reset Package Caches
2. Clean Build Folder（⌘⇧K）
3. 重新 Build（⌘B）

### Q2: 运行时崩溃 "[Firebase/Core][I-COR000003] The default Firebase app has not yet been configured"

**原因**：`GoogleService-Info.plist` 未添加到项目

**解决**：
1. 检查文件是否在 `TiredApp/` 目录
2. 在 Xcode 项目导航器中确认文件存在
3. 右键文件 → Show File Inspector → 确认 Target Membership 勾选了 `TiredApp`

### Q3: 无法登录/注册

**原因**：Firebase Authentication 未启用

**解决**：
1. 前往 Firebase Console
2. Authentication → Sign-in method
3. 启用 Email/Password

### Q4: 创建任务后看不到

**原因**：Firestore 安全规则未配置或过于严格

**解决**：
1. Firebase Console → Firestore Database → Rules
2. 临时使用测试规则（30天后失效）：
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
3. 发布规则

### Q5: Xcode 版本太旧

**错误信息**：需要 Xcode 15.0 或更高版本

**解决**：
1. 前往 Mac App Store 更新 Xcode
2. 或降低项目最低 iOS 版本：
   - Project Settings → Deployment Target → iOS 16.0

## 📱 真机测试

如果要在真机上测试：

1. 连接 iPhone 到 Mac
2. Xcode → Settings → Accounts → 添加 Apple ID
3. 项目 Settings → Signing & Capabilities
4. Team 选择你的个人团队
5. 选择你的 iPhone 作为运行目标
6. 点击 Run

首次运行需要在 iPhone 上信任开发者证书：
- 设置 → 通用 → VPN与设备管理 → 开发者App → 信任

## 🎉 完成！

现在你已经成功运行了 Tired App！

## 📚 下一步

- 阅读 [README.md](../README.md) 了解项目架构
- 查看 [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) 理解数据模型
- 探索代码：从 `TiredApp.swift` 开始
- 自定义 UI：修改 `Views/` 下的 SwiftUI 文件
- 添加功能：参考 `Services/` 和 `ViewModels/`

## 💬 获取帮助

遇到问题？

- 查看 [GitHub Issues](https://github.com/yourrepo/tired/issues)
- 提交新 Issue
- 联系开发者

祝你开发愉快！🚀
