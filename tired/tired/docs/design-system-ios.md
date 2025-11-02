# tired Design System（iOS）

- 對齊 Apple HIG：Clarity / Deference / Depth / Consistency
- 採 iOS Semantic Colors 與 Dynamic Type；大面積材質使用 Materials

## Tokens（對應 SwiftUI）

- radius: xs=8, sm=12, md=16, lg=24
- spacing: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32
- shadow: level1=y2 b8 12%, level2=y8 b24 16%
- font: display=SF Pro, text=SF Pro, mono=SF Mono
- color:
  - bg=systemBackground, bg2=secondarySystemBackground, card=systemGroupedBackground
  - label=label, secLabel=secondaryLabel
  - tint=systemBlue, success=systemGreen, warn=systemOrange, danger=systemRed
- material: nav=systemUltraThinMaterial, sheet=systemThinMaterial

備註：顏色全面採用 iOS Semantic Colors，自動支援深/淺色與高對比。

### 最新補充（2025-10）

- 新增按鈕樣式 API：
  - `tPrimaryButton(fullWidth:)`、`tSecondaryButton(fullWidth:)`
- 卡片樣式：
  - `cardStyle(padding:radius:shadowLevel:)`；統一邊框/陰影/留白
- 狀態元件：
  - `AppLoadingView`、`AppEmptyStateView`、`AppErrorView`
- 多語系封裝：
  - `L.s("key")`；新增 `zh-Hant.lproj` 與 `en.lproj`

## 版面與導覽

- Tab Bar：收件匣｜訊息｜群組｜我
- Navigation Stack：工具列按鈕（+、搜尋、更多）
- 分割：iPad/Mac 使用 NavigationSplitView（群組→頻道→內容）

## 元件映射（關鍵路徑）

- 統一收件匣：卡片列表 + `AppEmptyStateView`/`AppLoadingView`
- 廣播詳情：Sheet + 固定 CTA（ack/form/vote）
- 10 秒點名：FullScreenCover + 大號 QR + 倒數
- 打卡：MapKit + Floating Panel（地理圍欄內顯示主按鈕）
- 匿名 Q&A：List + Toolbar 篩選（最新/熱門/待回覆）
- ESG OCR：Document Scanner + Progress View
- 個人頁：Editable Sections + 「鎖頭」可見度選擇器 + Preview as

## 無障礙（Accessibility）

- 文字對比 ≥ 4.5:1，尊重「提高對比度」與「動作減少」
- 觸控目標 ≥ 44x44pt，VoiceOver 具備替代文案
- 動態字級：使用 `.font(.headline/.body)` 等可縮放字體，避免自訂固定尺寸

## Haptics

- 成功：UINotificationFeedbackGenerator.success
- 警示：warning；輕點：UIImpactFeedbackGenerator.light

