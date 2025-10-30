# tired｜全域 AI 架構＋群組型平台 PRD v1

- 專案：tired（多租戶群組平台｜學校／公司／社群／SME-ESG）
- 文件：全域 AI 架構＋群組型平台 PRD v1
- 版本：v1.0（草稿，可直接進工程拆解）
- 作者：產品／架構
- 更新：2025-10-25

---

## 1. 產品定位（One-liner）

任何組織都能建立「群組（Group）」並選擇類型與驗證等級，系統自動掛上相對應的能力包（Capability Pack）。成員以假名對外、依法可對人。平台內建：實名廣播、10 秒點名、公司打卡、ESG 碳盤查、情緒解碼、學習教練、群聊／私訊、活動與藍牙附近交友等模組。全域以五大 AI 引擎（理解／生成／決策／檢核／檢索）驅動。

---

## 2. 目標與非目標

### 2.1 產品目標（12–16 週）

- P0：群組＋能力包卡片、統一收件匣、廣播／需回條、群聊／私訊（含 Alias）、可自訂時間的 10 秒點名、公司打卡、活動／投票。
- P1：SSO/SCIM、匿名 Q&A、ESG 帳單 OCR→報告、班級／部門儀表板、雙簽揭示流程＋審計匯出。
- P2：薪資單檢視（加密 Blob）、LMS/HRIS 雙向、裝置端 AI、HSM/租戶私鑰、智慧電表／Email 帳單自動擷取。

### 2.2 非目標（本期不做）

- 自研薪資計算引擎（先整合既有系統僅做檢視/投遞）。
- 即時醫療判斷功能（情緒/CBT 皆為自助，非醫療）。

---

## 3. 使用者／角色

- 一般成員（學生、員工、社團成員）。
- 群組管理者（老師/TA、主管/HR、社團幹部）。
- 租戶管理者（學校／公司單位管理端）。
- 法遵／DPO（可與管理者共同審批揭示）。
- 平台維運（不可見 PII，僅遙測與審計）。

---

## 4. 群組模型

Group = { type, capability_pack, addons[], verification_level(L0~L3), alias_policy, retention_policy }

### 4.1 類型 × 能力包（預設功能）

| 類型 | 能力包（Capability Pack） | 典型場景 |
| --- | --- | --- |
| School | Campus Pack：實名廣播、10 秒點名（QR+GPS/BLE+裝置指紋）、作業/考試排程、班級儀表板、緊急廣播、（選）匿名情緒聚合 | 班級公告、到課簽到、校安 |
| Company | Company Pack：全員廣播（需回條/需回覆）、打卡/外勤、部門儀表板、匿名 Q&A、（選）薪資單檢視 | 內部通告、出勤、匿名提問 |
| Community | Community Pack：群組公告、活動/票券、投票、審核/邀請制、近場入群（QR/Beacon） | 社團、系學會 |
| SME-ESG | ESG Pack：帳單 OCR→係數套用→PDF 月報、碳挑戰儀表板 | 供應鏈碳盤查 |

Add-ons（跨類型可掛）：情緒解碼、學習教練、個資掌門人、校園/公司碳挑戰、薪資單檢視、LMS/HRIS 串接、藍牙附近交友…

### 4.2 驗證等級（Verification Level）

- L0 未驗證：基本聊天/公告/活動/投票。
- L1 網域/郵箱：實名廣播、需回條、名單。
- L2 文件驗證：10 秒點名、打卡、匿名 Q&A（可依法揭示）、Webhook/CSV 同步。
- L3 合約/法遵：薪資單檢視、ESG 報告、HSM/自管金鑰、Break-Glass、審計匯出。

---

## 5. 功能需求（含你要求的細項）

### 5.1 訊息／廣播／私訊

- 頻道模式：關閉／只讀（需回條/表單）／一般聊天／匿名聊天（Alias）。
- 強制閱讀：政策公告需閱讀＋小測驗；未讀補催；回條報表。
- 私訊（DM）：關閉／同群成員／開放（需同意）；陌生訊息請求匣；封鎖/檢舉；慢速模式。
- 附件：圖片、檔案、表單、投票、活動票。
- 審核：違規字典、舉報、管理員靜音/關閉匿名。

### 5.2 校園（Campus Pack）

- 10 秒點名：時間可自訂（群組預設 → 課程策略 → 單次場次覆蓋）。
  - 參數：開窗/關窗（相對課表或絕對時間）、最短停留、遲到門檻、地理圍欄（GPS/BLE）、QR 旋轉頻率（15–60s）。
  - 反作弊：限時 QR + GPS/BLE + 裝置指紋、風險分（多帳/模擬器/異地）、離線簽到券、（選）二次驗證。
- 作業/考試排程 & 智慧提醒、未交名單。
- 班級儀表板：到課率、準時繳交、既讀率、風險名單。
- 匿名情緒聚合（選）：只回班級趨勢，不回個人。
- 緊急廣播：停課、校安，一鍵全校。
- LMS/SIS 串接（L2+）：名單/課表/成績/作業狀態。

### 5.3 公司（Company Pack）

- 全員廣播（需回條/需回覆、表單/簽收、未讀補催）。
- 打卡/外勤：GPS/地理圍欄/Beacon；補登與覆核；據點白名單。
- 匿名 Q&A / 意見箱（Alias 提問；管理端可依法揭示）。
- 部門儀表板：打卡異常、回條率、問答熱點。
- 薪資單檢視（L3）：個人端到端加密 Blob；停留即銷毀快取；來源由 HR/Payroll 系統推送。

### 5.4 SME-ESG（ESG Pack）

- 帳單 OCR（關鍵欄位＋置信度）。
- 係數套用與計算（版本標註）。
- 一鍵報告：PDF/CSV；方法、假設、原始證據鏈（影像、OCR JSON、係數版本）。
- 儀表板：月/季/年趨勢、熱點；部門/班級減碳挑戰。
- Email/智慧電表（選）。

### 5.5 個人／社群（Community Pack）

- 社團/公開群（開放／邀請／審核）。
- 活動/票券：報名、QR 票、入場掃描。
- 藍牙附近（安全交友、選）：時間窗、臨時 ID 輪換、雙向同意、快速封鎖/檢舉。
- 興趣圈/徽章（可隱藏）。

### 5.6 Add-ons：情緒解碼／學習教練／個資掌門人

- 情緒解碼：文字/語音日誌、情緒/實體 NLP、CBT 提示卡（非醫療）。
- 學習教練：任務分拆、番茄鐘、薄弱地圖、情緒×效率對齊。
- 個資掌門人：App 權限體檢、風險建議、一鍵跳系統設定；外洩監測/訂閱清理（選）。

---

## 6. 安全／隱私／合規

- 雙層身分：RealID（租戶私域保存，不給平台/開發者查看）＋ Scoped Alias（群內對外顯示）。
- 揭示（Unmask）：雙簽（HR+法遵 / 導師+系辦）＋事由代碼＋全程審計＋（依法可延遲）通知。
- E2EE：私訊預設端到端加密；群聊依 L2/L3 群組政策採留存或合法稽核密封。
- 留存策略：群組設定（保留天數、法律保全、刪除與可攜）。
- 反濫用：關鍵字攔截、速率限制、行為風險分、黑名單。

---

## 7. 資料模型（Firestore 節選）

```json
users/{uid} {
  profiles: { personal:{}, campus:{}, company:{} },
  devices: [ {platform, pushToken, deviceHash} ],
  consents: [ {key, grantedAt} ]
}
orgs/{orgId} { type, name, verification_level, keys:{kmsKeyRef}, settings:{} }
groups/{groupId} {
  orgId, type, capability_pack, verification_level,
  addons:["mood","learning","privacy","esg"],
  chat_mode:"off"|"broadcast"|"normal"|"alias",
  dm_policy:"off"|"members"|"open",
  retention_policy:{ e2ee:true, keep_days:30, legal_hold:false },
  alias_allowed:true
}
members/{groupId}_{uid} { roles:["member"|"moderator"|"admin"|"hr"|"dpo"], aliasIdEnc, realIdRef }
channels/{channelId} { groupId, name, mode, requires_ack:true? }
messages/{msgId} { channelId, fromAliasId, payload, createdAt, e2ee?:true }
attendance_policies/{policyId} { scope:"group"|"course", start_offset_min, end_offset_min, min_dwell_sec, late_after_min, geofence:{lat,lng,radius}, qr_rotate_sec, require_ble }
courses/{courseId} { groupId, name, teacherId, schedule[] }
attendance_sessions/{sessId} { courseId, policyId, open_at, close_at, qr_seed, status }
attendance_checks/{checkId} { sessId, uid, ts, device_hash, gps, ble_ok, risk_score, status }
clock_sessions/{id} { groupId, siteId, geofence, open_at, close_at }
clock_records/{id} { uid, siteId, ts, device_hash, gps, status }
bills/{id} { orgId, month, fileRef, ocrJson, parsed, factorVersion }
reports/{id} { orgId, month, pdfRef, assumptions, evidenceRefs[] }
paystubs/{id} { orgId, uid, month, blobEncRef, ttl }
unmask_requests/{id} { orgId, targetAlias, reasonCode, approvers[], status, auditRef }
audits/{id} { actor, action, target, ts, details }
```

索引：messages(channelId, createdAt)、attendance_checks(sessId, uid)、members(groupId, roles)、reports(orgId, month)。

---

## 8. API（節選）

- POST /v1/groups（建立群組，選 type→自動掛能力包）。
- POST /v1/channels/:id/broadcast（廣播；需回條/表單）。
- POST /v1/attendance/policies、/sessions、/check。
- POST /v1/clock/records（打卡）。
- POST /v1/esg/bill:ocr → POST /v1/esg/report:generate。
- POST /v1/payroll/paystub:publish（加密 Blob）。
- POST /v1/unmask:request、/unmask:approve（雙簽）。
- Webhook：message.ack, attendance.closed, clock.recorded, esg.report.ready, policy.violation, unmask.approved。

---

## 9. 全域 AI 架構

### 9.1 五大引擎

1. 理解引擎：OCR/ASR/NER/情緒。
2. 生成引擎：公告撰稿、摘要、報告文字、CBT/學習提示卡。
3. 決策引擎：未讀/未交/遲到/壓力/碳排的 nudges。
4. 檢核引擎：內容審核、PII 脫敏、反騷擾、合規檢查。
5. 檢索引擎（RAG）：規章/FAQ/係數庫→答案附來源與版本號。

### 9.2 事件流（Orchestration）

```
Event -> Router(依 groupType/verification) -> Guardrails(脫敏)
     -> Tools(OCR/NLP/RAG/LLM) -> Decider(誰/何時/什麼內容) -> Logger(審計/成本)
```

### 9.3 佈署策略

- 裝置端：情緒、關鍵詞、藍牙配對（Core ML/NNAPI, int8 量化）。
- 雲端：高精度 OCR／長文摘要／公告潤稿／RAG 問答（先脫敏）。
- 快取：同文件 24h 命中；降級：雲掛掉→裝置端短摘要 fallback。

---

## 20. 系統開發邏輯（落地藍圖）

本章提供 12–16 週可落地的工程藍圖（契約先行、Trunk-based、Feature Flags），以 P0 打通「收件匣｜廣播回條｜10 秒點名（可自訂）｜打卡｜群聊/私訊（含 Alias）」為北極星。

- 原則與 SLO（P0）
  - 讀取 P95 ≤ 250ms、寫入 P95 ≤ 400ms；推播達送 P95 ≤ 2s；點名端到端 ≤ 3s。
  - 契約先行（OpenAPI + 事件），裝置端優先，AI 不作權威（RAG+附來源）。
- 里程碑（建議 12 週）
  - W1–W2 基建：CI/CD、Design Tokens、認證、骨架頁（Tab/收件匣/群組/我）。
  - W3–W4 訊息域：廣播發佈/需回條、收件匣聚合、推播、追催排程。
  - W5–W6 出勤域：10 秒點名（QR 輪換+GPS/BLE+裝置指紋）、結算/風險分。
  - W7–W8 公司域：打卡據點/地理圍欄、補登/覆核、部門儀表板。
  - W9–W10 社交域：群聊/私訊（Alias/可見度）、舉報/審核。
  - W11–W12 AI 與硬化：廣播撰稿、摘要/追催、觀測/告警、滲透測試、TestFlight。
- 分層與模組
  - App：SwiftUI（UI）/ ViewModel / Service（API/Storage/Push）。
  - Edge/Backend：API Gateway → App Service（REST）→ Event Bus（Pub/Sub）→ Workers（OCR/NLP/RAG/追催）。
  - Data：Firestore + Storage + 向量庫（RAG）+ OTel。
- 契約與事件（節選）
  - POST /v1/broadcasts、POST /v1/broadcasts/{id}/ack
  - POST /v1/attendance/policies、/sessions、/check
  - POST /v1/clock/records、GET /v1/profile/{uid}
  - 事件：broadcast.posted / broadcast.acked / attendance.opened / attendance.checked / attendance.closed / clock.recorded
- 資料與遷移
  - 以 orgId/groupId 作分區鍵；高頻清單加索引；寫入帶幂等鍵。
  - version 欄位 + Worker 批次升版；回滾腳本與快照集合（attendance 結束寫快照）。
- CI/CD 與品質閘（最小可用）
  - iOS：Build + Unit/UI Tests + Lint；簽章自動管理；TestFlight。
  - Backend：Test → Build → Deploy（stage 自動 Smoke，人工核准推 prod）。
- 安全/隱私
  - 雙層身分（RealID + Scoped Alias）、雙簽揭示、E2EE（DM）、欄位級加密（敏感）、留存策略與審計。

附錄：
- Story/AC/DoD 模板、日誌格式、錯誤碼、Git Workflow、專案結構樣板，見 docs 與 .github/workflows。


---

## 10. Prompt 套件庫（可直接用）

> 以「指令名」管理；支援變數；回傳 JSON schema（行動按鈕、截止、對象）。

### 10.1 /broadcast.drafter

System：你是校園/企業公告專家，語氣正式、清楚，必含「行動與截止」。避免冗詞，120–180 字，必要連結置後。
User（變數）：{audience, topic, when, where, actions:[ack|form|vote], deadline}
Output：3 版文案＋CTA JSON。

CTA Schema

```json
{
  "cta": {"type": "ack"|"form"|"vote", "label": "已知悉", "deadline": "2025-11-09T23:59:00+08:00" }
}
```

### 10.2 /thread.summarize

任務：將頻道近 24h 對話轉成「需處理清單＋關鍵點」；避免主觀推測；列出@人與截止。

### 10.3 /esg.report.draft

System：你是 ESG 顧問。基於解析後欄位與係數庫，生成「方法、假設、限制」，禁止臆測，必附來源與版本。
Input：{parsed_fields, factorVersion, evidenceRefs[]}

### 10.4 /study.split

把作業拆為 30–90 分鐘子任務，附估時、先後、所需前置材料；避免模糊動詞。

### 10.5 /cbt.nudge

口吻溫和，不涉醫療；<=120 字重評卡＋10 分鐘可完成的小步驟；若對象為學生，結合課務提醒。

### 10.6 /qa.cluster

將匿名問題群聚去重、排序優先級，產生建議回覆草稿（最終需管理者審核）。

---

## 11. RAG 索引設計

### 11.1 索引庫結構

- kb_chunks{ groupId, source, chunk, embedding, version, lang, tags[], updatedAt }
- 向量模型：all-MiniLM-L6-v2 或同級；chunk 600–1000 tokens，重疊 100。

### 11.2 來源與更新

| 類型 | 來源 | 週期 | 備註 |
| --- | --- | -- | --- |
| School | 校規、課綱、行事曆、教室資訊 | 每週 | 新版自動重編索引，保留 version |
| Company | HR/IT 政策、SOP、FAQ | 每週 | 需權限映射到群組 |
| ESG | 係數庫、政府公告、供應商表 | 每月 | 嚴格版本化與來源鏈 |

### 11.3 查詢流程

1. 檢索（BM25+向量）→ 2) 濾權限（groupId/roles）→ 3) 生成答案（附來源）→ 4) 紀錄 query 與命中文件。

---

## 12. A/B 實驗計畫

| 場景 | 變因 | KPI | 样本量＆門檻 |
| --- | --- | --- | --- |
| 廣播追催 | D-1/H-2/H-0 vs D-1/H-1 | 24h 既讀率 | 每組≥500 通知；提升≥+5pp |
| CBT 提示卡 | 模板 A vs B | Nudge 後 7 日準時交付率 | 每組≥200 人；+8% |
| 點名反作弊 | 門檻/QR 旋轉/地理圍欄 | 誤判率/作弊攔截率 | 誤判<1%，攔截率>80% |
| ESG OCR | 版型模型 A/B | 欄位 F1 | F1≥0.97 |

統計：雙尾 z-test；顯著性 α=0.05；功效≥0.8。

---

## 13. KPI & 儀表板

- 廣播：24h 既讀 ≥95%，回條完成 ≥90%。
- 校園：點名中位數 ≤30s；準時繳交率 +10%。
- 公司：打卡異常 <2%；匿名 Q&A 參與 ≥50%。
- ESG：月報 ≤30 分鐘；OCR F1 ≥0.97；PoC ≥2 家。
- 隱私：揭示申請 100% 雙簽與審計；刪除請求 100% 成功；0 外洩。

---

## 14. 路線圖（建議）

- P0（8 週）：群組＋能力包卡片、收件匣、廣播/需回條、群聊/私訊（Alias）、點名（可自訂）、打卡、活動/投票。
- P1（+8 週）：SSO/SCIM、匿名 Q&A、ESG OCR→報告、班級/部門儀表板、揭示雙簽＋審計匯出。
- P2（滾動）：薪資單檢視、LMS/HRIS 雙向、裝置端 AI、HSM/私鑰、智慧電表/Email 擷取。

---

## 15. 風險與反制

- 介面複雜：群組首頁卡片＋固定 4 分頁＋統一收件匣。
- 匿名濫用：頻率限制、違規字典、舉報、管理員靜音、必要時揭示。
- 薪資/合規風險：先做檢視/投遞；L3 才開；加密與審計。
- 點名作弊：限時 QR+地理圍欄+裝置指紋；高風險標紅覆核；重要場次二次驗證。
- 雲成本：裝置端先跑可跑的；快取/冷儲存；批次運算。

---

## 附錄 A：老師端／管理端流程（摘要）

- 廣播 → AI 撰稿（3 版）→ 選擇 → 需回條/表單 → 發送 → 追催 → 儀表板。
- 點名 → 套用策略模板（一般/嚴格/演講）→ 開場 → 收斂 → 異常覆核 → 匯出報表。
- 打卡 → 據點管理 → 地理圍欄 → 異常覆核 → 匯出。
- ESG → 上傳帳單 → OCR → 係數套用 → 報告草稿 → 審閱 → 匯出。

## 附錄 B：偽碼（節選）

```ts
postBroadcast({groupId, bullets, audience}) {
  const variants = await LLM.generate("/broadcast.drafter", {bullets, audience, policy: kb(groupId)})
  const chosen = humanPick(variants)
  publish(chosen)
  scheduleNudges(audience, chosen.deadline) // D-1/H-2/H-0
}

closeAttendance(sessId) {
  const checks = loadChecks(sessId)
  const features = featurize(checks) // gps距離, ble, deviceHash多重, 時差...
  const scored = isoForest(features)
  flagOnThreshold(scored, 0.95)
}

onFileUploaded(path) {
  const img = load(path)
  const redacted = redactPII(img)
  const ocr = await OCR.parse(redacted)
  const norm = normalize(ocr, factorVersion())
  const draft = await LLM.generate("/esg.report.draft", {norm})
  const pdf = renderPDF(draft, norm, evidence=[path, ocr.json])
  saveReport(pdf, meta={factorVersion, sources})
}
```

---

說明：本 PRD 已可直接交付工程拆卡（Issue）與設計 Wireframe。若需，我可另出：

- Wireframe 清單（群組首頁卡片、統一收件匣、點名策略面板、聊天/私訊設定、揭示審批流程）
- API OpenAPI 規格草稿（YAML）
- RAG 索引器 Script（Chunk/Embed/Upsert）
- A/B 實驗追蹤事件（Analytics 事件表）

---

## 附錄 C：品牌命名與識別（tired）

- 品牌定位：tired = 反向命名（把疲累交給系統處理），讓人「不再 tired」。
- 口號（Tagline）：Make work & study less tired. ／ 「把麻煩交給系統，讓你不再累。」
- 語氣（Tone）：冷靜、可靠、帶一點幽默（避免說教）。
- 字標（Logotype）：全小寫 `tired`，圓角幾何體；`i` 的點做成發光（提醒/微 Nudge 的象徵）。
- 色票（Palette）：
  - Midnight Navy #0B1B2B（信任）
  - Neon Mint #3CF2C8（提示、互動）
  - Amber #FFC24B（警示/截止）
  - Cloud #F2F5F7（背景）
- 圖標（Icon）：一半月牙 + 通知點（把疲累變成一個可控提醒）。
- 產品文案（Microcopy）：
  - 「今天先處理三件事，就不再 tired。」
  - 「你的簽到我幫你守著，專心上課就好。」
- 域名方向（僅建議，未檢核可用性）：tired.app、trytired.app、gettired.app、tired.im、tired.one、tired.school、tired.work。
- 風險備註：中文語境「tired=累」可能偏負面 → 用副標與視覺把「減累」的正向價值說清楚；社群貼文以「今天少一點 tired」的反諷語感呈現。

---

## 16. 個人頁（Profile）— 可編輯＆對特定對象開放

需求：像 Threads 一樣好編、好看，但每個欄位都能控管可見對象；支援「假名/真名」雙層、群組別名視圖、臨時分享與存取稽核。

### 16.1 使用者價值

- 只想讓同學/同事看到的資料，不必公開給所有人。
- 不同群組看到不同「卡片」（例如：課程裡顯示學號，社團裡顯示興趣）。
- 臨時分享（24–72h）給特定人或特定群組，不留永久痕跡。

### 16.2 功能清單（P0 / P1 / P2）

P0

- 個人頁基本欄位：頭像、封面、顯示名稱、別名（Alias）、簡介（Bio 140字）、連結（最多2個）、興趣標籤（最多5個）。
- 欄位級可見度（Visibility per-field）：公開 / 僅好友 / 同群成員 / 同組織 / 僅自己 / 自訂清單。
- 自訂清單（Audience List）：可建立 10 個以內的清單（例如「同組報告成員」）。
- 群組視圖：同一個人可為不同群組設定不同的頭像/別名/欄位可見度（Scoped Profile）。
- 預覽視角（Preview as）：切換看「陌生人/好友/同群成員/管理員」會看到什麼。
- 私訊與回覆權限：不允許 / 僅好友 / 同群成員 / 任何人（經同意）。

P1

- 臨時分享連結：選擇欄位集合＋對象＋有效期（24/48/72h），可一鍵撤銷。
- 欄位歷程與回滾：最近 10 次編輯可回復；顯示修改時間。
- 存取紀錄：近 30 天「誰看過你的特定欄位」（聚合呈現，不暴露個資）。
- 徽章與驗證：校方驗證、公司驗證、社團幹部徽章；可選是否顯示。

P2

- 內容保護：螢幕截圖偵測提示（不阻擋僅提醒）。
- 智慧建議：AI 建議你的 Bio/標籤（裝置端草稿→可選上雲潤稿）。
- 更多欄位型別：多連結（Link-in-profile 卡）、置頂貼文（Highlights）。

### 16.3 UI 流程

- 個人頁：上半部（頭像/封面/顯示名/別名），中段（Bio/標籤/連結），下段（徽章/置頂/群組卡）。
- 編輯面板：每個欄位右側有「鎖頭圖示」→ 點擊開啟可見度選擇器。
- 預覽：頂部有 `Preview as` 下拉（陌生人/好友/同群/管理員/自訂）。
- 臨時分享：選取欄位 → 設對象（人/群/清單）→ 設有效期 → 產生分享卡與連結。

### 16.4 欄位與權限矩陣（摘要）

| 欄位 | 預設可見度 | 可見度選項 | 群組差異化 |
| --- | --- | --- | --- |
| 頭像/封面 | 同群成員 | 全部 | ✅（可為群組指定不同頭像） |
| 顯示名稱 | 公開 | 全部 | ✅（可設群組別名） |
| 別名（Alias） | 同群成員 | 全部 | ✅（每群組一個 Alias） |
| Bio | 好友 | 全部 | ✅ |
| 連結（x2） | 好友 | 全部 | ✅ |
| 興趣標籤（x5） | 同群成員 | 全部 | ✅ |
| 學號/工號（選） | 僅自己 | 全部 | ✅（常設為同群/同組織） |

預設遵循「最小曝光」原則：敏感/身份欄位預設不可見。

### 16.5 資料結構（Firestore 建議）

```
users/{uid}/profile_fields/{fieldId} {
  key: "displayName|bio|link1|tags|studentId|avatar",
  type: "text|link|tags|image",
  value: any,                              // 加密存放敏感值
  visibility: {
    mode: "public|friends|group|org|private|custom",
    groups?: [groupId],                    // mode=group
    orgs?: [orgId],                        // mode=org
    listIds?: [listId],                    // mode=custom
    expiresAt?: ts                         // 臨時分享（覆蓋）
  },
  scoped?: { [groupId]: { overrides... } }, // 群組特化：例如不同頭像/別名
  updatedAt: ts, version: n
}

users/{uid}/audience_lists/{listId} {
  name: "報告小組",
  members: [uid...],
  smartRule?: { type: "sameGroup|sameOrg|role", args: {...} }
}

profile_shares/{token} {
  ownerUid, fields: ["bio","link1","tags"],
  scope: { uids?:[], groups?:[], listIds?:[] },
  expiresAt, createdAt, revoked: false
}
```

### 16.6 API（節選）

- GET /v1/profile/:uid?viewer=:viewerUid&groupId=:gid → 回傳「對該觀察者可見」的欄位。
- PATCH /v1/profile/fields → 多欄位更新（含可見度設定）。
- POST /v1/profile/share → 產生臨時分享 token。
- DELETE /v1/profile/share/:token → 撤銷分享。
- GET /v1/profile/audit（P1）→ 近 30 天聚合存取紀錄。

### 16.7 安全/隱私

- 雙層身分：RealID 僅在租戶私域；對外一律 Alias 展示。
- 欄位加密：學號/工號等敏感欄位以欄位級加密保存。
- 預設最小：敏感欄位預設 private；第一次開放會有風險提示。
- 審計：臨時分享/可見度變更/管理端揭示全留跡；可匯出。
- 未成年人保護：針對年齡 <18 的帳號限制公開範圍與 DM 設定（依地區法規）。

### 16.8 與聊天/群組整合

- 聊天室頭像與名牌顯示群組 Alias；點擊名牌 → 開啟「群組視圖 Profile 卡」。
- 開啟新 DM 時顯示對方對你可見的迷你卡（Bio/共同群/互動權限）。
- 群組成員名單支援依「自訂欄位」篩選（例如只看顯示專長者）。

### 16.9 KPI

- 7 日內完成個人頁編輯率 ≥60%。
- 欄位級可見度設定使用率 ≥40%。
- 臨時分享功能使用率 ≥15%，撤銷率 <5%。
- 因可見度導致的私訊騷擾投訴率 <0.5%。

### 16.10 開發排程（建議）

- W1–W2：Profile 基本欄位＋欄位級可見度（含 UI）；群組視圖（頭像/別名）。
- W3–W4：Audience List、自訂清單；預覽視角；私訊/回覆權限策略。
- W5–W6：臨時分享 token＋撤銷；欄位歷程/回滾；敏感欄位加密。
- W7–W8：徽章/驗證；存取紀錄聚合；整合聊天迷你卡與名單篩選。

---

## 17. 視覺/互動設計系統（iOS 風格｜tired Design System）

備註：你提到「iOS 26」，目前未有該版本；本規格以最新 Apple Human Interface Guidelines 的 iOS 設計語彙為準（Deference/Clarity/Depth、Dynamic Type、Semantic Colors、SF Symbols、Materials）。同時保留 Android 的自適應策略。

### 17.1 核心理念（與 Apple 對齊）

- 清晰（Clarity）：層級分明、字級可縮放、語意色彩。
- 禮讓（Deference）：內容優先、控件低調、留白充足、毛玻璃材質（Materials）。
- 深度（Depth）：分層、視差、柔和陰影與動線。
- 一致（Consistency）：iOS 控件外觀、手勢、回饋一致；使用 SF Symbols。

### 17.2 版面與導覽

- Tab Bar（底部 4 分頁）：收件匣｜訊息｜群組｜我（iOS 標準高度，浮動毛玻璃）。
- Navigation Stack：各分頁進入次層頁；右上操作用 工具列按鈕（例如 +、搜尋、三點）。
- 群組切換：首頁頂部用 Segmented Control 或 圓角膠囊按鈕（最多 3 個釘選群組；更多放在選擇器）。
- 大螢幕：iPad / Mac Catalyst 使用 NavigationSplitView（側邊欄：群組→頻道→內容）。

### 17.3 設計 Token（iOS 語意化）

```json
{
  "radius": {"xs":8, "sm":12, "md":16, "lg":24},
  "spacing": {"xs":4, "sm":8, "md":12, "lg":16, "xl":24, "xxl":32},
  "shadow": {"level1":"y2 b8 12%", "level2":"y8 b24 16%"},
  "font": {"display":"SF Pro", "text":"SF Pro", "mono":"SF Mono"},
  "color": {
    "bg":"systemBackground",
    "bg2":"secondarySystemBackground",
    "card":"systemGroupedBackground",
    "label":"label",
    "secLabel":"secondaryLabel",
    "tint":"systemBlue",
    "success":"systemGreen",
    "warn":"systemOrange",
    "danger":"systemRed"
  },
  "material": {"nav":"systemUltraThinMaterial", "sheet":"systemThinMaterial"}
}
```

說明：顏色全部使用 iOS Semantic Colors，自動支援深/淺色與高對比。

### 17.4 字體與字級（Dynamic Type）

- 字體：SF Pro / SF Pro Rounded（重點數字/徽章）/ SF Compact（Apple Watch 或極小裝置）。
- 層級（以 iOS Dynamic Type 為基準）：Large Title 34 / Title 28 / Headline 17 / Body 17 / Subhead 15 / Footnote 13 / Caption 12。
- 規範：支援使用者字級設定（Content Size Category）。

### 17.5 控件樣式

- 按鈕：膠囊圓角 radius.lg；主要色 tint；次要描邊 quaternarySystemFill 背景。
- 卡片：分組列表樣式（Inset Grouped）；卡面可用 systemGroupedBackground＋細分隔線。
- 清單：iOS 標準 Cell（Leading Icon（SF Symbols）/ Title / Subtitle / Trailing Value）。
- 搜尋：Navigation Bar 內嵌 Search；支援 Pull to Search。
- 表單：使用 Inset Grouped + Footer 說明文字（小字、次標色）。

### 17.6 動效與回饋

- 動效：UIKit/SwiftUI 預設 Spring；轉場遵守減速曲線；避免過度炫技。
- 毛玻璃與模糊：material.nav/sheet 控制；透明度遵從 iOS 規則。
- 觸覺回饋（Haptics）：
  - 成功：UINotificationFeedbackGenerator.success
  - 警示：warning
  - 輕點：UIImpactFeedbackGenerator.light
- 聲音：系統音效優先；自訂音量上限。

### 17.7 無障礙（Accessibility）

- 對比度：遵守 iOS 的 提高對比度設定；文字對比 ≥ 4.5:1。
- 可觸目標：最小 44x44pt。
- VoiceOver：所有控制附替代文案；分段式讀序。
- 動作減少：尊重 Reduce Motion 與 Reduce Transparency。

### 17.8 元件對應（tired 功能 → iOS 組件）

| 功能 | iOS 組件 | 說明 |
| --- | --- | --- |
| 統一收件匣 | UITableView / List (SwiftUI) Inset Grouped | 每段一個群組；Cell 右側有行動（Ack/開啟）。 |
| 廣播詳情 | Sheet + Large Title | 下拉關閉；底部固定 CTA（回條/表單）。 |
| 10 秒點名 | FullScreenCover + 大號 QR | 上方倒數；底部狀態（GPS/BLE/裝置）。 |
| 打卡 | MapKit + Floating Panel | 地理圍欄內顯示「打卡」主按鈕。 |
| 匿名 Q&A | List + Toolbar 篩選 | 分類 Tabs（最新/熱門/待回覆）。 |
| ESG OCR | Document Scanner + Progress View | 上傳→解析→報告卡。 |
| 個人頁 | ScrollView + Editable Sections | 每欄位右側可見度鎖頭；Preview as。 |

### 17.9 iOS / Android 自適應

- iOS：如上規格，完全採用 HIG 語彙（毛玻璃、Semantic Colors、SF Symbols）。
- Android：自動切換 Material 3（Color Roles、Elevation、Motion）；資訊架構一致，視覺控件隨平台切換。

### 17.10 開發落地（Flutter / React Native）

- Flutter：
  - CupertinoApp + ThemeData 對應 Token；cupertino_list_section.dart、CupertinoSearchTextField；blur 用 BackdropFilter。
  - flutter_map/mapbox_gl for Map；mobile_scanner 文件掃描。
  - cupertino_icons（僅基本），推薦自帶 SF Symbols 素材（遵照授權）。
- React Native：
  - react-native-ios-kit/@react-navigation；expo-blur 毛玻璃；react-native-haptic-feedback。
  - iOS 使用 SF Symbols（SVG/Font）；Android 換 Material Icons。

### 17.11 風險與反方建議

- 只做 iOS 風格會讓 Android 用戶突兀 → 已規劃自適應：同結構、不同控件皮膚。
- 複製 iOS 動效與材質成本高 → 以 Token 驅動、優先核心路徑，二階段再補毛玻璃與細節。
- 字級/對比不符 → 強制檢核（自動化 UI Test：WCAG、Dynamic Type、Hit Area）。

---

# 18. 現代化 UI 規格（tired Modern Pack v1）

> 目標：在遵循 Apple HIG 的前提下，呈現極簡、層次、細節豐富的現代視覺與互動。用 Token 駆動，跨 iOS/Android 一致的 IA，平台原生的觀感。

## 18.1 視覺語言

* 配色（Semantic-First + 現代強化）

  * 以 iOS Semantic Colors 為底（systemBackground/label/secondaryLabel/separator）。
  * 重點色梯度（Accent Gradient）：Neon Mint → Azure（#3CF2C8 → #00AEEF），用於主要按鈕、進度條、醒目狀態。
  * 警示用 systemOrange、危險用 systemRed、成功用 systemGreen，不自定飽和紅，避免刺眼。
* 層次（Depth）：Material 毛玻璃 + 細邊框（1px hairline = separator），卡片輕投影（y2 b8 12%）。
* 形狀（Shape）：圓角階層 8/12/16/24（列表/卡/大卡/全寬模組）。
* 排版：SF Pro + Dynamic Type；標題用 Large Title，正文 Body 17pt，支援使用者字級。

## 18.2 版面節奏與格線

* 8pt 系統（4pt 細節）；全頁左右安全邊距 16pt。
* 分段：群組首頁以卡片區塊呈現（廣播/點名/打卡/ESG/活動/投票…），每段之間留白 16–24pt。
* 空態（Empty States）：單色線稿插畫 + 一句行動導向文案 + 主 CTA（例：「今天沒待辦，去完成一個學習任務吧！」）。

## 18.3 元件樣式（現代化細節）

* 按鈕（Buttons）

  * Primary：填色 + 漸層（Mint→Azure），字色 white，半徑 16。
  * Secondary：tint 邊框 + 透明底；Hover/Pressed 有 1%–3% 高亮。
  * Tertiary：純文字 + 觸覺回饋（light）。
  * Loading：按鈕內置 ActivityIndicator；禁止跳動布局。
* 卡片（Cards）：Grouped Inset，卡面 systemGroupedBackground，1px 邊、陰影 level1；卡頂標題 + 次行描述 + 右上角操作圖示。
* 清單（Cells）：主標/副標/尾端數值；支援滑動操作（Pin/完成/刪除）。
* 輸入（Forms）：即時驗證 + 錯誤說明（次標色）；輸入框圓角 12、描邊 quaternarySystemFill。
* 搜尋：頂部嵌入式 Search；進入狀態時全局淡化（Defer to content）。
* 聊天泡泡：膠囊型，己方用 Accent 漸層淡版，對方用 secondarySystemBackground；支援回覆/反應（長按出現 Action Sheet）。

## 18.4 動效與微互動

* 節奏：入場/轉場 180–280ms；列表插入 120–160ms；可見區延遲動畫分批（stagger 40ms）。
* 觸覺回饋：Primary 成功 success；警示 warning；按鈕輕點 light；長按 medium。
* Skeleton/Shimmer：資料載入用骨架屏與微弱 Shimmer，最多 600ms。
* 狀態轉換：按鈕變 loading 不改大小；卡片展開用`spring(response: 0.25, damping: 0.9)`。

## 18.5 暗色模式（Luminous Dark）

* 以 systemBackground 深階為底；卡片使用 secondarySystemBackground；分隔線 separator。
* 漸層降低亮度 15%（避免螢光刺眼）。
* 圖表線條提高對比度（+10%）確保可讀。

## 18.6 資料視覺化（ESG/儀表板）

* 單一重點色 + 次色（Success/Warning/Danger），避免彩虹圖。
* 折線/長條/圓餅：半徑 4；網格線使用 tertiaryLabel。
* 互動：長按顯示 Tooltip（數值 + 單位 + 時間）；支援滑動區間縮放。

## 18.7 版面範例（關鍵頁）

1. 統一收件匣：Large Title「收件匣」，上方 Segmented（全部/待回覆/已讀）；卡片列出：公告（回條）、點名（倒數）、打卡（到站）、作業（截止）。
2. 群組首頁：上方群組切換；下方能力卡（廣播、點名、打卡、ESG、活動、投票…）。每卡：圖示 + 標題 + 次行；右上角設定。
3. 10 秒點名：全螢幕 QR + 倒數；底部狀態列（GPS/BLE/裝置）；成功後轉成綠色勾 + Haptic。
4. 廣播詳情：大標題 + 來源/時間；內文卡片化；底部固定 CTA「已知悉」；上滑看回覆/統計。
5. 個人頁：可編輯卡區段；每欄右側鎖頭（可見度）；`Preview as` 切換視角；背景可用柔和漸層或毛玻璃。

## 18.8 Android 自適應（Material 3）

* Color Roles 對應疲累色票；Elevations 映射到卡片陰影；Motion 用標準曲線。
* 控件使用 M3（FilledButton/TonalButton/TextButton、NavigationBar）但資訊架構一致。

## 18.9 Token 與主題（交付）

* Design Tokens（JSON）：顏色（語意+漸層）、字級、間距、圓角、陰影、動效時間。
* 平台主題：

  * Flutter：ThemeData + Cupertino 自訂；BackdropFilter 毛玻璃；自製 GradientButton。
  * React Native：ThemeContext + expo-blur；react-native-reanimated 動效。
* 圖示庫：SF Symbols（iOS）；Material Symbols（Android）；自繪 16 個品牌圖標（SVG）。

## 18.10 驗收標準（Modern）

* 列表/卡片/按鈕/表單四大元件達到設計 Token；
* 深淺色切換 0 bug；
* Dynamic Type 與 VoiceOver 無阻礙；
* Skeleton/Shimmer 上線；
* 3 個關鍵頁（收件匣/群組首頁/點名）通過設計走查；
* Android 達到 M3 等價體驗（動效、Elevation、色角、元件）。
