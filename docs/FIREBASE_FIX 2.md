# Firebase 配置錯誤修復指南

## 錯誤訊息
"The supplied auth credential is malformed or has expired"

## 可能原因

這個錯誤通常表示 Firebase 配置有問題。請按照以下步驟檢查：

### 1. 確認 GoogleService-Info.plist 已添加到 Xcode 專案

1. 在 Xcode 中，打開專案導航器
2. 找到 `GoogleService-Info.plist` 檔案
3. 如果找不到，請：
   - 右鍵點擊專案 → `Add Files to "tired"...`
   - 選擇 `TiredApp/GoogleService-Info.plist`
   - ✅ 勾選 `Copy items if needed`
   - ✅ 確認 `Add to targets` 中勾選了你的 App target

4. 如果檔案存在，請確認：
   - 右鍵點擊 `GoogleService-Info.plist`
   - 選擇 `Show File Inspector`
   - 在 `Target Membership` 中確認勾選了你的 App target

### 2. 確認 Bundle ID 一致

1. 在 Xcode 中，選擇專案 → 選擇你的 App target → `General`
2. 查看 `Bundle Identifier`（例如：`tw.pu.tiredteam.tired`）
3. 確認這個 Bundle ID 與 `GoogleService-Info.plist` 中的 `BUNDLE_ID` 一致
4. 確認這個 Bundle ID 與 Firebase Console 中註冊的 iOS App 的 Bundle ID 一致

### 3. 確認 Firebase Authentication 已啟用

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 選擇你的專案：`tired-634e9`
3. 左側選單 → `Build` → `Authentication`
4. 確認 `Sign-in method` 標籤中：
   - ✅ `Email/Password` 已啟用
   - 如果未啟用，點擊 `Email/Password` → 啟用 → 保存

### 4. 清理並重新編譯

在 Xcode 中：

1. `Product` → `Clean Build Folder`（或按 `⌘⇧K`）
2. 關閉 Xcode
3. 刪除 `DerivedData`：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
4. 重新打開 Xcode
5. 重新編譯：`⌘B`
6. 運行：`⌘R`

### 5. 檢查 Console 輸出

運行 App 時，查看 Xcode 底部的 Console，應該會看到：

```
✅ 找到 GoogleService-Info.plist: /path/to/GoogleService-Info.plist
✅ Firebase 初始化成功
```

如果看到：
```
❌ 錯誤: 找不到 GoogleService-Info.plist
```

表示檔案未正確添加到專案。

## 快速檢查清單

- [ ] `GoogleService-Info.plist` 在 Xcode 專案導航器中可見
- [ ] `GoogleService-Info.plist` 的 Target Membership 已勾選
- [ ] Xcode 專案的 Bundle ID 與 `GoogleService-Info.plist` 中的 `BUNDLE_ID` 一致
- [ ] Firebase Console 中已啟用 Email/Password 認證
- [ ] 已清理並重新編譯專案

## 如果問題仍然存在

1. 重新下載 `GoogleService-Info.plist`：
   - 前往 Firebase Console
   - 專案設定 → 你的 iOS App
   - 下載新的 `GoogleService-Info.plist`
   - 替換專案中的檔案

2. 確認 Firebase 專案狀態：
   - 確認專案沒有被暫停或刪除
   - 確認 API 配額未用盡

3. 檢查網路連線：
   - 確認設備/模擬器可以連接到網路
   - 確認沒有防火牆阻擋 Firebase 服務



