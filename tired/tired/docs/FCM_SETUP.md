# Firebase 推播（FCM）設定指南（iOS）

本專案已在 Xcode 啟用 Push 與 Background Modes，且分 Debug/Release 使用不同的 entitlements。

## 1) APNs Key 綁定（Firebase Console）
- 進入 Firebase Console → Project settings → Cloud Messaging
- Apple app configuration → Upload your APNs authentication key
- 上傳 `.p8` 檔案，填入 Key ID 與 Team ID，Bundle ID 要與 `tw.pu.tiredteam.tired` 一致
- 儲存後，FCM 即可透過 APNs 發送推播

提示：發開發版可用 TestFlight 或 Developer 签發憑證；本專案由 entitlements 決定 dev/prod 環境（見下）。

## 2) Xcode 設定
- Capabilities：Push Notifications、Background Modes → Remote notifications 已啟用
- Entitlements 檔：
  - Debug → `tired/tired/tired.dev.entitlements`（aps-environment=development）
  - Release → `tired/tired/tired.prod.entitlements`（aps-environment=production）

## 3) 取得裝置 Token 與註冊
- App 啟動會：
  - 請求通知權限
  - 註冊 APNS/FCM token → 寫入 `users/{uid}/devices/{token}`
- 實機測試：模擬器不會取得 APNS token

## 4) 送出測試推播
- 於 Firebase Console → Cloud Messaging → Send your first message
- 選擇 iOS app，Target 選單輸入測試裝置（或用 topic）
- 發送通知後，若 App 在前景，會以橫幅顯示（`NotificationService` 設定）

## 5) 常見問題
- 沒有收到推播：
  - 確認 APNs Key 綁定成功
  - 確認在實機上允許通知
  - 確認使用 Release build（對 production）或 Debug build（對 development）
  - 檢查 Firestore 是否有寫入 `users/{uid}/devices/{token}`

