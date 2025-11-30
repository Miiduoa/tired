# Xcode 構建錯誤修復指南

## 🔧 修復 Xcode 構建數據庫錯誤

如果遇到以下錯誤：
```
error: accessing build database ".../Build/Intermediates.noindex/XCBuildData/build.db": not an error
The build service has encountered an internal inconsistency error
```

### 解決方法：

1. **清理構建文件夾**
   - 在 Xcode 中：`Product` → `Clean Build Folder` (Shift + Cmd + K)
   - 或者手動刪除 DerivedData：
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/tired-*
     ```

2. **清理 Xcode 緩存**
   ```bash
   # 清理模塊緩存
   rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
   
   # 清理構建數據
   rm -rf ~/Library/Developer/Xcode/DerivedData/tired-*/Build/Intermediates.noindex
   ```

3. **重啟 Xcode**
   - 完全退出 Xcode
   - 重新打開專案

4. **如果問題持續**
   ```bash
   # 完全清理所有 DerivedData
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

## ✅ 已修復的 InfoRow 衝突

### 問題
- `EventDetailView.swift` 和 `TaskDetailView.swift` 中都有 `InfoRow` 結構定義
- 即使一個是 `private`，在同一個模塊中仍可能造成衝突

### 修復
- 將 `EventDetailView.swift` 中的 `InfoRow` 重命名為 `EventInfoRow`
- 更新所有使用該結構的地方

### 修改的文件
- `EventDetailView.swift`: `InfoRow` → `EventInfoRow`

## 🚀 構建步驟

1. 清理構建文件夾
2. 重新構建專案
3. 如果仍有問題，執行上述清理命令






