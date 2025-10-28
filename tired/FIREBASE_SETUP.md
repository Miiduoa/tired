# Firebase 設定指南

## 1. 建立 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「建立專案」
3. 輸入專案名稱：`tired-app`
4. 選擇是否啟用 Google Analytics（建議啟用）
5. 選擇 Analytics 帳戶或建立新帳戶
6. 點擊「建立專案」

## 2. 設定 iOS 應用程式

1. 在 Firebase Console 中，點擊「新增應用程式」→ iOS
2. 輸入 iOS 套件 ID：`com.tired.app`
3. 輸入應用程式暱稱：`tired`
4. 下載 `GoogleService-Info.plist` 檔案
5. 將 `GoogleService-Info.plist` 拖放到 Xcode 專案中（確保選擇「Copy items if needed」）

## 3. 啟用 Firebase 服務

### 啟用 Authentication
1. 在 Firebase Console 中，前往「Authentication」
2. 點擊「開始使用」
3. 前往「Sign-in method」標籤
4. 啟用「電子郵件/密碼」提供者
5. 點擊「儲存」

### 啟用 Firestore Database
1. 在 Firebase Console 中，前往「Firestore Database」
2. 點擊「建立資料庫」
3. 選擇「以測試模式開始」（稍後可以調整安全規則）
4. 選擇資料庫位置（建議選擇 `asia-east1` 或 `us-central1`）

## 4. 設定 Firestore 安全規則

在 Firestore Database → 規則 中，設定以下規則：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 使用者只能存取自己的資料
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 群組資料
    match /groups/{groupId} {
      allow read, write: if request.auth != null;
    }
    
    // 成員資料
    match /members/{memberId} {
      allow read, write: if request.auth != null;
    }
    
    // 訊息資料
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    // 其他集合的規則...
  }
}
```

## 5. 更新 GoogleService-Info.plist

將下載的 `GoogleService-Info.plist` 檔案替換專案中的範本檔案，確保包含正確的：
- API_KEY
- GOOGLE_APP_ID
- GCM_SENDER_ID
- PROJECT_ID
- STORAGE_BUCKET

## 6. 測試認證功能

1. 在 Xcode 中建置並執行應用程式
2. 測試註冊新帳號
3. 測試登入現有帳號
4. 測試登出功能
5. 測試密碼重設功能

## 7. 注意事項

- 確保 Firebase SDK 已正確安裝（已在 Package.resolved 中確認）
- 確保 `GoogleService-Info.plist` 已正確添加到 Xcode 專案
- 在生產環境中，請調整 Firestore 安全規則以符合您的安全需求
- 考慮啟用 Firebase App Check 以增加安全性

## 8. 故障排除

如果遇到問題：
1. 檢查 `GoogleService-Info.plist` 是否正確添加到專案
2. 確認 Bundle ID 與 Firebase 專案中的設定一致
3. 檢查 Firebase Console 中的 Authentication 設定
4. 查看 Xcode 控制台中的錯誤訊息
