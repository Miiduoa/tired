# Google 登入設定指南

## 已完成的工作

✅ 已添加 Google 登入功能到 `AuthService.swift`
✅ 已在 `LoginView.swift` 中添加「使用 Google 登入」按鈕
✅ 已配置 URL Scheme 到 `Info.plist`
✅ 已在 `TiredApp.swift` 中添加 URL callback 處理

## 需要在 Xcode 中完成的步驟

### 1. 添加 GoogleSignIn SDK

由於這是一個 Xcode 專案（不是 Swift Package），你需要在 Xcode 中手動添加 GoogleSignIn SDK：

#### 方法 A：使用 Swift Package Manager（推薦）

1. 在 Xcode 中，選擇專案 → 選擇你的 App target → `Package Dependencies` 標籤
2. 點擊 `+` 按鈕
3. 輸入以下 URL：
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```
4. 選擇版本：`7.0.0` 或最新版本
5. 點擊 `Add Package`
6. 在 `Add Package to Project` 對話框中：
   - ✅ 確認選擇了你的 App target
   - 點擊 `Add Package`

#### 方法 B：使用 CocoaPods（如果專案使用 CocoaPods）

如果你使用 CocoaPods，在 `Podfile` 中添加：

```ruby
pod 'GoogleSignIn'
```

然後運行：
```bash
pod install
```

### 2. 確認 Firebase Authentication 已啟用 Google Sign-In

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 選擇你的專案：`tired-634e9`
3. 左側選單 → `Build` → `Authentication`
4. 點擊 `Sign-in method` 標籤
5. 找到 `Google` 並點擊
6. 確認已啟用（如果未啟用，點擊「啟用」）
7. 確認 `Project support email` 已設置
8. 點擊「保存」

### 3. 確認 URL Scheme 配置

已自動配置在 `Info.plist` 中：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.566724358335-04e0heqf7hato4hv2kb62pkfk9fgd366</string>
        </array>
    </dict>
</array>
```

這個 URL Scheme 是從 `GoogleService-Info.plist` 中的 `REVERSED_CLIENT_ID` 自動提取的。

### 4. 測試 Google 登入

1. 在 Xcode 中編譯並運行 App（⌘R）
2. 在登入畫面點擊「使用 Google 登入」按鈕
3. 應該會彈出 Google 登入視窗
4. 選擇你的 Google 帳號並授權
5. 登入成功後應該會自動進入主畫面

## 故障排除

### 錯誤：「無法獲取 Google Client ID」

- 確認 `GoogleService-Info.plist` 已正確添加到 Xcode 專案
- 確認 `Target Membership` 已勾選你的 App target
- 確認 `CLIENT_ID` 在 `GoogleService-Info.plist` 中存在

### 錯誤：「無法獲取視圖控制器」

- 這通常發生在 App 啟動時，重試即可
- 如果持續發生，檢查 `LoginView` 是否正確顯示

### 錯誤：「Google 登入失敗：...」

- 確認 Firebase Console 中已啟用 Google Sign-In
- 確認 Bundle ID 與 Firebase 專案中的一致
- 確認 URL Scheme 已正確配置
- 檢查 Xcode Console 中的詳細錯誤訊息

### URL Scheme 不工作

- 確認 `Info.plist` 中的 URL Scheme 與 `GoogleService-Info.plist` 中的 `REVERSED_CLIENT_ID` 一致
- 清理並重新編譯專案（⌘⇧K，然後 ⌘B）

## 注意事項

- Google 登入需要網路連線
- 首次使用時，系統會要求用戶授權
- 如果用戶已經用 Google 帳號登入過，系統會自動使用該帳號
- 登出時會同時登出 Google Sign-In 和 Firebase Auth



