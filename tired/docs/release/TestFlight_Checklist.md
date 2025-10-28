# TestFlight 發布清單（iOS）

此清單確保每次 TestFlight/審核提交具備必要資訊與合規聲明。

- 隱私權字串（Info.plist）
  - `NSCameraUsageDescription` 拍攝/掃描 QR 用途（點名/票券）。
  - `NSLocationWhenInUseUsageDescription` 地理圍欄/打卡/點名驗證用途。
  - `NSBluetoothAlwaysUsageDescription` 近場驗證（BLE）用途。
  - `NSMicrophoneUsageDescription`（若使用語音記錄/情緒）。
  - `NSPhotoLibraryAddUsageDescription`（若儲存影像）。
- App 審核備註（App Review Notes）
  - 測試帳號與步驟（登入、加入群組、發佈廣播、回條、點名/打卡）。
  - 若使用第三方登入，提供測試憑證或測試模式說明。
  - 若含匿名/揭示流程，描述法遵管控（雙簽/審計）。
- 打包與版本
  - 語義版號（MAJOR.MINOR.PATCH），build 逐次遞增。
  - 變更日誌（Changelog）附關鍵修正與風險。
- QA 與可及性
  - Unit/UITest 綠燈；Dynamic Type/VoiceOver/對比檢查通過。
  - 主要路徑：廣播回條、點名、打卡、收件匣聚合、推播到達。
- 遙測與觀測
  - Crash/性能監控開啟（如 Sentry/Firebase Crashlytics）。
  - 重要指標：latency{p50,p95}、ack_rate_24h、attendance_success、push_delivery_latency。
- 法規與資料
  - 條款/隱私權政策連結有效；刪除帳號流程說明。
  - PII 僅於租戶私域保存；裝置端快取有 TTL；加密政策與留存策略清楚。

> 備註：TestFlight 外測前，先跑一次小規模內測（10–30 人），收集裝置相容性與效能數據。
