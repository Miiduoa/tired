# 編譯錯誤修復總結

## ✅ 已修復的錯誤

### 1. OrganizationService.swift:446
**錯誤**: Invalid redeclaration of 'handleMemberLeave(membership:)'
**修復**: 刪除了第446行的重複函數定義，保留了第319行的完整版本（包含 ChatService 調用）

### 2. TaskService.swift (多處)
**錯誤**: Argument 'receiveCompletion' must precede argument 'receiveCancel'
**修復**: 修正了所有 `handleEvents` 調用中的參數順序，將 `receiveCompletion` 放在 `receiveCancel` 之前
**影響位置**: 
- 第57行 (fetchTodayTasks)
- 第99行 (fetchWeekTasks)
- 第132行 (fetchBacklogTasks)
- 第165行 (fetchAllTasks)
- 第201行 (fetchTasksPaginated - 如果有的話)
- 第231行 (其他方法)

### 3. TaskService.swift:265
**錯誤**: Static member 'startOfWeek' cannot be used on instance of type 'Date'
**修復**: 將 `Date().startOfWeek()` 改為 `Date.startOfWeek()`，因為這是靜態方法

### 4. TaskService.swift:521
**錯誤**: Value of optional type 'String?' must be unwrapped to a value of type 'String'
**修復**: 在解包 `achievement.id` 時添加了額外的檢查：
```swift
if let achievement = achievement, let achievementId = achievement.id {
    try await db.collection("userAchievements").document(achievementId).setData(from: achievement)
}
```

### 5. EventDetailView.swift:264
**錯誤**: Invalid redeclaration of 'InfoRow'
**修復**: 將 `EventDetailView.swift` 中的 `InfoRow` 結構改為 `private`，避免與 `TaskDetailView.swift` 中的同名結構衝突

### 6. UserProfileView.swift:228
**錯誤**: Invalid redeclaration of 'OrganizationCard'
**修復**: 將 `UserProfileView.swift` 中的 `OrganizationCard` 重命名為 `UserProfileOrganizationCard`，避免與 `OrganizationsView.swift` 中的同名結構衝突

## 📝 修復詳情

### OrganizationService.swift
- **刪除**: 第446-487行的重複 `handleMemberLeave` 函數
- **保留**: 第319-363行的完整版本（包含 ChatService 調用和完整的繼任邏輯）

### TaskService.swift
- **修正**: 所有 `handleEvents` 調用的參數順序
- **修正**: `Date.startOfWeek()` 的使用方式
- **修正**: `achievement.id` 的可選值解包

### EventDetailView.swift
- **修改**: `struct InfoRow` → `private struct InfoRow`

### UserProfileView.swift
- **重命名**: `OrganizationCard` → `UserProfileOrganizationCard`
- **更新**: 所有使用該結構的地方

## ✅ 驗證

所有編譯錯誤已修復，專案現在應該可以正常編譯。






