
# tired iOS Starter (SwiftUI)

[![iOS CI](https://github.com/OWNER/REPO/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/ios-ci.yml)
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

## 測試
- 本地 UI 測試（自動偵測模擬器並自動登入測試使用者）
  - `make ios-uitest`
- 本地建置與啟動 App
  - `make ios-run` 或直接執行 `tired/scripts/ios_build_run.sh`

## CI（GitHub Actions）
- 已提供 workflow：`.github/workflows/ios-ci.yml`
- 觸發條件：push 至 `main` 或 `master`，或手動 `workflow_dispatch`
- 執行內容：
  - 選定 Xcode 版本後，自動偵測模擬器並跑 UI 測試（自動登入測試使用者）
  - 測試結果以 `.xcresult` 形式上傳 artifacts（失敗時可下載查看）
- 如需修改觸發分支，請編輯 `on.push.branches` 與 `on.pull_request` 區段。

> 注意：上方 CI 徽章請將 `OWNER/REPO` 替換為你的 GitHub 倉庫路徑。
