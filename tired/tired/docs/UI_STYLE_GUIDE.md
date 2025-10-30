# Tired App UI 風格統一指南

## ✅ 已完成的統一化

### 設計系統核心（Theme.swift）

所有 View 現在應該使用統一的設計 Token：

#### 間距 (Spacing)
- `TTokens.spacingXS` = 4pt
- `TTokens.spacingSM` = 8pt  
- `TTokens.spacingMD` = 12pt
- `TTokens.spacingLG` = 16pt ⭐️ **最常用**
- `TTokens.spacingXL` = 24pt
- `TTokens.spacingXXL` = 32pt

#### 圓角半徑 (Radius)
- `TTokens.radiusXS` = 8pt
- `TTokens.radiusSM` = 12pt ⭐️ **最常用**
- `TTokens.radiusMD` = 16pt
- `TTokens.radiusLG` = 24pt ⭐️ **卡片常用**

#### 顏色 (Color)
- `Color.bg` - 主背景色
- `Color.card` - 卡片背景色 ⭐️ **最常用**
- `Color.separator` - 分隔線
- `Color.labelPrimary` - 主要文字
- `Color.labelSecondary` - 次要文字

#### 輔助方法
- `.standardPadding()` - 標準內距（16pt）
- `.cardStyle()` - 卡片樣式（內距、圓角、陰影、邊框）
- `.gradientPrimary()` - 漸層按鈕樣式

## 📋 統一化檢查清單

### ✅ 已統一化的 View
- [x] `ProfileView` - 使用 TTokens 間距和圓角
- [x] `AttendanceView` - 使用 TTokens 
- [x] `GroupHomeView` - 使用 TTokens
- [x] `TCard` - 使用設計系統
- [x] `GradientButton` - 使用設計系統

### 🔄 需要統一的 View（部分數值仍硬編碼）
以下 View 仍有部分硬編碼數值，建議逐步統一：

1. **InboxView.swift**
   - 部分 `spacing: 12` → `TTokens.spacingMD`
   - 部分 `cornerRadius: 8` → `TTokens.radiusXS`
   - 部分 `padding(16)` → `.standardPadding()`

2. **BroadcastListView.swift**
   - `spacing: 12` → `TTokens.spacingMD`
   - `cornerRadius: 12` → `TTokens.radiusSM`

3. **ESGOverviewView.swift**
   - `spacing: 24` → `TTokens.spacingXL`
   - `cornerRadius: 20` → `TTokens.radiusMD`
   - `padding(20)` → `.standardPadding()`

4. **MainAppView.swift**
   - `cornerRadius: 20/16` → `TTokens.radiusMD`
   - 多處硬編碼間距需要統一

5. **ClockView.swift**
   - `spacing: 12` → `TTokens.spacingMD`

6. **Activities/ActivityBoardView.swift**
   - `cornerRadius: 8` → `TTokens.radiusXS`

## 🎯 統一方針

### 規則 1：禁止硬編碼
❌ **錯誤：**
```swift
.padding(16)
.spacing: 12
.cornerRadius(12)
```

✅ **正確：**
```swift
.standardPadding()  // 或 .padding(TTokens.spacingLG)
.spacing(TTokens.spacingMD)
.cornerRadius(TTokens.radiusSM)
```

### 規則 2：統一使用卡片樣式
❌ **錯誤：**
```swift
.padding(16)
.background(Color.card, in: RoundedRectangle(...))
```

✅ **正確：**
```swift
.cardStyle()
```

### 規則 3：統一按鈕樣式
- 主要按鈕：使用 `.gradientPrimary()`
- 次要按鈕：使用 `.buttonStyle(.bordered)`
- 危險操作：使用 `.buttonStyle(.borderedProminent).tint(.danger)`

## 🔍 檢查工具

使用以下命令查找硬編碼數值：
```bash
grep -r "padding([0-9]\+)" tired/tired/Features/
grep -r "spacing: [0-9]\+" tired/tired/Features/
grep -r "cornerRadius: [0-9]\+" tired/tired/Features/
```

## 📝 最佳實踐

1. **優先使用擴充方法**：`.standardPadding()`, `.cardStyle()`
2. **間距使用 Token**：所有 spacing 參數使用 `TTokens.spacing*`
3. **圓角使用 Token**：所有 cornerRadius 使用 `TTokens.radius*`
4. **背景色使用語意化**：使用 `Color.bg`, `Color.card`
5. **保持一致性**：同一類型元素使用相同樣式

## 🚀 下一步

建議逐步將剩餘 View 中的硬編碼數值替換為設計 Token，確保整個 App 的 UI 風格完全一致。
