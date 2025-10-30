# 功能需求整理清單（待補資料）

> 依照目前程式架構，要把每個功能完整落實，需要以下資訊或決策。請依模組填寫，之後我會按優先順序逐一開發。

---

## 1. 使用者與登入流程
- [ ] Firebase Auth 供應商是否僅 Email/Apple/Google？是否需要電話、匿名或企業 SSO？
- [ ] Apple / Google 的回呼 URL 是否需要額外自訂（例如多租戶導向）？
- [ ] 登入後是否還需要額外的「租戶切換權限檢查」API？

## 2. 租戶／會員資料
- [ ] Firestore 或後端 API 的實際資料模型（collections、document 欄位）
- [ ] 租戶列表是否支援分頁 / 搜尋？API 參數為何？
- [ ] 會員角色對應的功能限制（目前程式預設管理員/一般成員）

## 3. 收件匣（Inbox）
- [ ] Firestore `groups/{tenantId}/inbox/{docId}` 實際欄位與 state 流程
- [ ] Ack 後是否要紀錄額外資訊（備註、照片、GPS...）
- [ ] 是否支援批次操作 / 篩選條件（例如只看「需回覆」）

## 4. 公告（Broadcast）
- [ ] API 或 Firestore 集合路徑、欄位定義
- [ ] 回條（ack）後是否要觸發推播 / 後端 webhook
- [ ] 附件（圖片、PDF）處理方式（Firebase Storage？）

## 5. 活動牆／動態（Activities）
- [ ] 事件類型與欄位（目前僅 broadcast/rollcall/clock/esg）
- [ ] 是否需要即時更新（listener）或可接受拉取

## 6. 出勤（Attendance）
- [ ] 點名 QR Code 的實際內容格式（目前僅 UUID）
- [ ] 驗證流程：學生掃描後是否走其他 API？是否需要顯示簽到狀態
- [ ] 遲到例外或重簽流程

## 7. 打卡（Clock）
- [ ] 打卡 API：簽到 / 簽退 / 異常申請
- [ ] GPS、NFC、Beacon 等需求
- [ ] 打卡紀錄的欄位與異常狀態定義

## 8. ESG 模組
- [ ] `esg_summary` / `esg_records` 的實際資料欄位
- [ ] 檔案上傳（帳單、照片）流程
- [ ] KPI 公式或報告輸出需求

## 9. Insights / 報表
- [ ] 報表來源（BigQuery？自建 API？）
- [ ] 欄位定義、單位、趨勢算法
- [ ] 是否需要下載 / 匯出

## 10. 訊息 / 即時通訊
- [ ] 是否整合外部平台（例如 Firebase Realtime Database、第三方 SDK）
- [ ] 基本功能（單聊、群聊、附件、已讀狀態）

## 11. 個人資料 / 偏好設定
- [ ] 編輯資料的欄位、驗證規則
- [ ] 偏好設定是否需同步到伺服器（目前僅 UserDefaults）

## 12. 推播與通知
- [ ] 是否使用 Firebase Cloud Messaging？Topic/Subscription 規則
- [ ] iOS 前台 / 背景處理規範

## 13. 測試與部署
- [ ] 需要跑哪些自動化測試（Unit / UI / Snapshot）
- [ ] CI/CD（Fastlane、Xcode Cloud、GitHub Actions）設定需求
- [ ] 上架流程（測試帳號、隱私權政策、審核文件）

---

### 請回覆方式建議
1. 直接在此清單於 IDE 內補上答案（打勾 + 補充文字），或
2. 另外回覆一份詳細需求文檔（例如 Google Sheet / Notion / Markdown）。

取得資料後，我會按照優先程度拆解成具體開發任務，逐步完成所有功能。隨時可以先指定「哪個模組要先完成」，我會以該模組為主進行實作。***
