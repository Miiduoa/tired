# 🚀 批量升級腳本

## 快速替換模式

### 1. 列表頁升級（List → ScrollView + LazyVStack）

**查找：**
```swift
List {
    ForEach(items) { item in
```

**替換為：**
```swift
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
```

**並在 ForEach 結尾添加動畫：**
```swift
                }
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(Double(index % 10) * 0.04),
                    value: items.count
                )
            }
            .padding(.top, 12)
        }
```

---

### 2. 卡片樣式升級

**查找：**
```swift
.cardStyle(padding: TTokens.spacingLG, radius: 20, shadowLevel: 1)
```

**替換為：**
```swift
.floatingCard()
```

或使用玻璃態：
```swift
.glassEffect(intensity: 0.7)
```

---

### 3. 按鈕升級

**查找普通按鈕：**
```swift
Button("操作") {
    // action
}
```

**替換為帶觸覺反饋：**
```swift
Button("操作") {
    HapticFeedback.light()
    // action
}
```

**主要按鈕使用流體樣式：**
```swift
Button("提交") {
    HapticFeedback.medium()
    // action
}
.fluidButton(gradient: TTokens.gradientPrimary)
```

---

### 4. 背景升級

**查找：**
```swift
.background(Color.bg.ignoresSafeArea())
```

**替換為漸層背景：**
```swift
.background {
    ZStack {
        Color.bg.ignoresSafeArea()
        GradientMeshBackground()
            .opacity(0.3)
            .ignoresSafeArea()
    }
}
```

---

### 5. 骨架屏升級

**查找：**
```swift
if isLoading {
    ProgressView()
}
```

**替換為：**
```swift
if isLoading && items.isEmpty {
    ScrollView {
        LazyVStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonCard()
                    .padding(.horizontal, 16)
                    .transition(.scale.combined(with: .opacity))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.08),
                        value: isLoading
                    )
            }
        }
        .padding(.top, 12)
    }
}
```

---

## 自動化升級命令

### 使用 sed 批量替換（macOS/Linux）

```bash
# 1. 備份所有文件
find tired/tired/Features -name "*.swift" -exec cp {} {}.backup \;

# 2. 批量添加觸覺反饋到 Button
find tired/tired/Features -name "*.swift" -exec sed -i '' \
  's/Button(/Button(\n                    HapticFeedback.light()/g' {} \;

# 3. 批量替換 List 為 ScrollView
find tired/tired/Features -name "*.swift" -exec sed -i '' \
  's/List {/ScrollView {\n            LazyVStack(spacing: 16) {/g' {} \;

# 4. 批量替換背景
find tired/tired/Features -name "*.swift" -exec sed -i '' \
  's/.background(Color.bg.ignoresSafeArea())/.background {\n                ZStack {\n                    Color.bg.ignoresSafeArea()\n                    GradientMeshBackground().opacity(0.3).ignoresSafeArea()\n                }\n            }/g' {} \;
```

⚠️ **注意**：自動化替換後需要手動檢查和調整！

---

## 手動升級優先級列表

### 高優先級（用戶最常用）
1. ✅ **GlobalFeedView** - 動態頁
2. ✅ **AuthView** - 登入頁
3. ✅ **ProfileView** - 個人資料
4. ✅ **ChatThreadView** - 聊天詳情
5. ⏳ **BroadcastListView** - 公告列表（進行中）
6. ⏳ **AttendanceView** - 點名頁
7. ⏳ **ClockView** - 打卡頁

### 中優先級（常用功能）
8. ⏳ **ChatListView** - 聊天列表
9. ⏳ **FriendsView** - 好友列表
10. ⏳ **ExploreView** - 探索頁
11. ⏳ **ESGOverviewView** - ESG 頁
12. ⏳ **ActivityBoardView** - 活動頁

### 低優先級（管理功能）
13. ⏳ **MemberManagementView** - 成員管理
14. ⏳ **InsightsView** - 分析頁
15. ⏳ **GroupHomeView** - 群組首頁

---

## 升級檢查清單

每個頁面升級後確認：

- [ ] 使用 ScrollView + LazyVStack（不是 List）
- [ ] 所有按鈕有觸覺反饋
- [ ] 卡片使用 .floatingCard() 或 .glassEffect()
- [ ] 背景有 GradientMeshBackground
- [ ] 列表項有進場動畫（交錯延遲）
- [ ] 骨架屏使用 SkeletonCard
- [ ] 空狀態使用 AppEmptyStateView
- [ ] 主要按鈕使用 .fluidButton()
- [ ] 圖標使用 SF Symbols
- [ ] 顏色使用設計系統（Color.tint 等）

---

## 批量測試命令

```bash
# 編譯檢查所有頁面
cd /Users/handemo/Desktop/Tired/tired
xcodebuild clean build -scheme tired 2>&1 | grep -E "(error:|warning:)"

# 如果沒有錯誤，運行
xcodebuild -scheme tired -destination 'platform=iOS Simulator,name=iPhone 15' | grep "BUILD SUCCEEDED"
```

---

## 快速升級模板使用

### 列表頁
```swift
ModernListPage(
    title: "標題",
    items: items,
    isLoading: isLoading,
    emptyTitle: "沒有內容",
    emptyIcon: "icon.name"
) { index, item in
    YourItemView(item: item)
}
```

### 詳情頁
```swift
ModernDetailPage(
    title: "標題",
    gradient: TTokens.gradientPrimary,
    headerContent: {
        HeaderContentView()
    },
    bodyContent: {
        BodyContentView()
    }
)
```

### 表單頁
```swift
ModernFormPage(
    title: "表單",
    submitTitle: "提交",
    isSubmitting: isSubmitting,
    canSubmit: isValid,
    content: {
        FormFieldsView()
    },
    onSubmit: handleSubmit
)
```

---

**批量升級建議：每次升級 5-10 個頁面，測試通過後繼續下一批。**

