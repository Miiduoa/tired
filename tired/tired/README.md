
# tired iOS Starter (SwiftUI)
這是可直接貼進 Xcode 專案的 **SwiftUI 起步碼**：已包含 Tab 結構、統一收件匣、群組首頁卡片、10 秒點名（QR + 倒數）、公告詳情（回條 CTA）、個人頁（欄位級可見度）。

## 使用方式
1. Xcode 建立 App 專案（SwiftUI + Swift）。
2. 將 `tired-starter` 內的 `*.swift` 檔案拖進你的專案（勾選 `Copy if needed`）。
3. 執行即可看到基本 UI。

## Info.plist 權限（之後需要時再加）：
- NSCameraUsageDescription（掃描 QR / 文件）
- NSLocationWhenInUseUsageDescription（地理圍欄打卡/點名）
- NSBluetoothAlwaysUsageDescription（BLE 附近/信標）
- NSMicrophoneUsageDescription（語音輸入/情緒）

## 下一步
- 串接 Firebase/Auth/Firestore。
- 把按鈕動作（已知悉/打卡/換 QR）換成 API 呼叫。
- 將 Theme 改成品牌漸層按鈕與 Token。
