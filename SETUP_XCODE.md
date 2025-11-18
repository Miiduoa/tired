# 建立 Xcode iOS App 專案指南

## 🎯 目標

將現有的 Swift Package 程式碼轉換為可以在 iOS 模擬器運行的 Xcode App 專案。

## 📋 步驟 1：在 Xcode 中建立新專案

1. **打開 Xcode**
   - 如果沒有安裝，請從 App Store 安裝

2. **建立新專案**
   - 選擇 `File → New → Project`
   - 選擇 `iOS` → `App`
   - 點擊 `Next`

3. **填寫專案資訊**
   ```
   Product Name: TiredApp
   Team: 選擇你的開發團隊（或個人團隊）
   Organization Identifier: tw.pu.tiredteam
   Bundle Identifier: tw.pu.tiredteam.tired
   Interface: SwiftUI
   Language: Swift
   ```
   - ⚠️ **重要**：取消勾選以下選項：
     - ❌ Use Core Data
     - ❌ Include Tests
   
4. **選擇保存位置**
   - 選擇 `/Users/handemo/Desktop/tired` 目錄
   - 點擊 `Create`

## 📋 步驟 2：整合現有程式碼

1. **刪除自動生成的檔案**
   - 在 Xcode 專案導航器中，找到 `TiredApp/` 目錄
   - 刪除其中的所有自動生成的檔案：
     - `TiredAppApp.swift`（或類似名稱）
     - `ContentView.swift`（如果有的話）
     - 其他自動生成的檔案
   - **保留** `TiredApp.xcodeproj` 本身

2. **添加現有程式碼**
   - 在專案導航器中，右鍵點擊 `TiredApp`（最上層的藍色圖標）
   - 選擇 `Add Files to "TiredApp"...`
   - 導航到並選擇整個 `TiredApp/` 資料夾（包含所有子目錄）
   - 在彈出視窗中：
     - ✅ 勾選 `Create groups`（不是 `Create folder references`）
     - ✅ 勾選 `Copy items if needed`
     - ✅ 確認 `Add to targets` 中勾選了 `TiredApp`
   - 點擊 `Add`

3. **確認檔案結構**
   專案導航器應該顯示：
   ```
   TiredApp
   ├── TiredApp/
   │   ├── TiredApp.swift
   │   ├── Info.plist
   │   ├── GoogleService-Info.plist
   │   ├── Models/
   │   ├── Services/
   │   ├── ViewModels/
   │   ├── Views/
   │   └── Utils/
   └── TiredApp.xcodeproj
   ```

## 📋 步驟 3：添加 Firebase SDK

1. **添加 Package Dependency**
   - 選擇 `File → Add Package Dependencies...`
   - 在搜尋框中輸入：`https://github.com/firebase/firebase-ios-sdk.git`
   - 點擊 `Add Package`

2. **選擇版本和產品**
   - 版本：選擇 `Up to Next Major Version` → `10.19.0`
   - 點擊 `Add Package`
   - 選擇以下產品（全部勾選）：
     - ✅ FirebaseAuth
     - ✅ FirebaseFirestore
     - ✅ FirebaseStorage
   - 點擊 `Add Package`

## 📋 步驟 4：配置專案設定

1. **選擇專案**
   - 在專案導航器中點擊最上層的 `TiredApp`（藍色圖標）

2. **General 設定**
   - 選擇 `TiredApp` target
   - 在 `General` 標籤中：
     - **Deployment Target**: `iOS 17.0`
     - **Bundle Identifier**: `tw.pu.tiredteam.tired`
     - **Display Name**: `Tired`

3. **Signing & Capabilities**
   - 選擇你的開發團隊
   - 如果沒有團隊，選擇 `Personal Team`（需要 Apple ID）

## 📋 步驟 5：確認 GoogleService-Info.plist

1. **檢查檔案**
   - 在專案導航器中找到 `TiredApp/GoogleService-Info.plist`
   - 確認檔案存在且內容正確

2. **確認 Target Membership**
   - 右鍵點擊 `GoogleService-Info.plist`
   - 選擇 `Show File Inspector`
   - 在 `Target Membership` 中確認勾選了 `TiredApp`

## 📋 步驟 6：運行應用程式

1. **選擇模擬器**
   - 在 Xcode 頂部工具列中，點擊裝置選擇器
   - 選擇一個 iOS 模擬器（例如：`iPhone 15 Pro`）

2. **運行應用程式**
   - 按 `⌘R` 或點擊左上角的運行按鈕 ▶️
   - Xcode 會：
     - 編譯專案
     - 啟動模擬器
     - 安裝並運行應用程式

3. **查看結果**
   - 模擬器應該會自動打開
   - 應用程式會自動啟動
   - 你應該看到登入界面

## 🐛 常見問題

### Q1: 編譯錯誤 "No such module 'FirebaseFirestore'"
**解決方案**：
- 確認已正確添加 Firebase SDK（步驟 3）
- 嘗試：`File → Packages → Reset Package Caches`
- 清理並重新編譯：`⌘⇧K` 然後 `⌘B`

### Q2: 找不到 GoogleService-Info.plist
**解決方案**：
- 確認檔案在 `TiredApp/` 目錄中
- 確認 Target Membership 已勾選

### Q3: 模擬器沒有啟動
**解決方案**：
- 確認已選擇模擬器（不是 "My Mac"）
- 嘗試手動啟動模擬器：`Xcode → Open Developer Tool → Simulator`

### Q4: 應用程式崩潰
**解決方案**：
- 檢查 Console 輸出（Xcode 底部）
- 確認 Firebase 已正確配置
- 確認 Bundle ID 與 GoogleService-Info.plist 中的一致

## ✅ 完成檢查清單

- [ ] Xcode 專案已建立
- [ ] 現有程式碼已添加到專案
- [ ] Firebase SDK 已添加
- [ ] 專案設定已配置（iOS 17.0, Bundle ID）
- [ ] GoogleService-Info.plist 已確認
- [ ] 應用程式可以在模擬器運行

## 🎉 完成！

如果所有步驟都完成，你應該可以在 iOS 模擬器中看到並使用 Tired App 了！

