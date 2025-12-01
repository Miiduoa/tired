# Phase 3: UI 更新總結

## ✅ 完成的功能

### 1. 更新 CreateOrganizationView

**新增層級選擇器**：
- 添加「組織層級」區塊，可選擇父組織
- 顯示當前選擇的父組織名稱和類型
- 支援清除父組織選擇

**動態類型限制**：
- 根據父組織類型自動限制可選的子組織類型
- 例如：選擇「學校」作為父組織 → 只能創建「系所」或「社團」
- 沒有父組織時，只能創建根組織類型（學校、公司、社團、專案、其他）

**課程資訊表單**（僅課程類型顯示）：
```swift
if shouldShowCourseInfo {
    // 顯示課程專屬欄位
    - 課程代碼（例如：CS101）
    - 學年（例如：2024）
    - 學期（例如：1）
    - 學分數
    - 最大選課人數（選填）
}
```

**表單驗證**：
- 課程類型時，必須填寫課程代碼、學年、學期、學分
- 創建按鈕在表單無效時禁用

### 2. 新增 ParentOrganizationPickerView

**功能特點**：
- 顯示用戶所有可創建子組織的組織列表
- 過濾出 `canHaveChildren == true` 的組織
- 顯示每個組織可創建的子組織類型
- 清晰的視覺設計，包含圖標和顏色

**空狀態處理**：
- 當沒有可用父組織時，顯示提示訊息
- 引導用戶先創建學校、公司或系所類型的組織

### 3. 圖標和顏色更新

**新增 .course 類型支援**：
```swift
case .course:
    icon: "book.closed"
    color: .green
```

**完整圖標列表**：
- 🏫 學校 (school): building.columns - 藍色
- 🏢 系所 (department): building.2 - 青色
- 📚 課程 (course): book.closed - 綠色
- 🎵 社團 (club): music.note.house - 紫色
- 💼 公司 (company): briefcase - 橘色
- 📁 專案 (project): folder - 薄荷色
- 🔘 其他 (other): square.grid.2x2 - 灰色

### 4. ViewModel 更新

**擴展 createOrganization 方法**：
```swift
func createOrganization(
    name: String,
    type: OrgType,
    description: String?,
    parentOrganizationId: String? = nil,  // 新增
    courseInfo: CourseInfo? = nil         // 新增
) async throws -> String
```

**智能提示訊息**：
- 根據組織類型顯示對應的成功訊息
- 例如：「學校創建成功！」、「課程創建成功！」

## 📱 使用流程範例

### 場景一：創建學校（根組織）

1. 點擊「創建」按鈕
2. 不選擇父組織（跳過層級選擇）
3. 輸入名稱：「國立XX大學」
4. 選擇類型：「學校」
5. 填寫描述（選填）
6. 點擊「創建」

**結果**：
- level = 0
- parentOrganizationId = nil
- 自動創建標準角色：擁有者、校長、行政人員、學生

### 場景二：創建系所（子組織）

1. 點擊「創建」按鈕
2. 點擊「選擇父組織」
3. 從列表選擇「國立XX大學」
4. 系統自動將類型限制為：「系所」或「社團」
5. 輸入名稱：「資訊管理系」
6. 系統自動選擇類型：「系所」
7. 點擊「創建」

**結果**：
- level = 1
- parentOrganizationId = 學校ID
- rootOrganizationId = 學校ID
- organizationPath = [學校ID]
- 自動創建標準角色：擁有者、系主任、教授、助教、學生

### 場景三：創建課程（子組織）

1. 點擊「創建」按鈕
2. 點擊「選擇父組織」
3. 從列表選擇「資訊管理系」
4. 系統自動將類型限制為：「課程」
5. 輸入名稱：「資料結構」
6. 系統自動選擇類型：「課程」
7. **填寫課程資訊**（表單自動顯示）：
   - 課程代碼：IM101
   - 學年：2024
   - 學期：1
   - 學分：3
   - 最大人數：60
8. 點擊「創建」

**結果**：
- level = 2
- parentOrganizationId = 系所ID
- rootOrganizationId = 學校ID
- organizationPath = [學校ID, 系所ID]
- courseInfo = { courseCode: "IM101", semester: "2024-1", ... }
- 自動創建標準角色：擁有者、授課教師、助教、學生

## 🎨 UI/UX 亮點

### 1. 智能表單
- 根據選擇動態顯示/隱藏欄位
- 自動驗證必填欄位
- 實時反饋表單狀態

### 2. 清晰的視覺層級
- 使用不同顏色區分組織類型
- 圖標直觀表達組織性質
- 層級選擇器清楚顯示父子關係

### 3. 引導式創建流程
- 先選父組織 → 系統自動限制類型 → 填寫資訊
- 避免用戶創建不合法的組織結構

### 4. Glassmorphic 設計風格
- 半透明磨砂玻璃效果
- 統一的視覺語言
- 現代化的 UI 風格

## 📊 資料流

```
用戶輸入
  ↓
CreateOrganizationView
  ├─ 收集基本資訊 (name, type, description)
  ├─ 收集層級資訊 (selectedParentOrg)
  └─ 收集課程資訊 (courseCode, semester, etc.)
  ↓
OrganizationsViewModel
  ├─ 組裝 Organization 物件
  ├─ 組裝 CourseInfo 物件（如果需要）
  └─ 調用 organizationService.createOrganization()
  ↓
OrganizationService
  ├─ 驗證父子組織類型合法性
  ├─ 自動設置 level, organizationPath
  ├─ 根據組織類型創建標準角色
  └─ 批次寫入 Firestore
  ↓
結果
  ├─ 成功：顯示 Toast 提示
  └─ 失敗：顯示錯誤訊息
```

## 🔄 與後端的整合

### Service 層自動處理

**OrganizationService.createOrganization()** 會自動：

1. **驗證層級結構**
   ```swift
   if let parentId = newOrg.parentOrganizationId {
       let parentOrg = try await fetchOrganization(id: parentId)
       guard parentOrg.type.canHaveChildren else {
           throw Error("父組織不支援子組織")
       }
       guard parentOrg.type.allowedChildTypes.contains(newOrg.type) else {
           throw Error("不允許的子組織類型")
       }
   }
   ```

2. **自動設置層級資訊**
   ```swift
   newOrg.level = parentLevel + 1
   newOrg.rootOrganizationId = parentOrg.rootOrganizationId ?? parentId
   newOrg.organizationPath = parentPath + [parentId]
   ```

3. **創建標準角色**
   ```swift
   let template = StandardRoleTemplate.from(newOrg.type)
   let roles = template.roles
   // 批次寫入所有角色
   ```

4. **批次原子性操作**
   - 組織文檔
   - 初始成員資格
   - 所有標準角色
   - 全部成功或全部失敗

## 📁 修改的文件

1. **Views/Organizations/OrganizationsView.swift**
   - 更新 CreateOrganizationView
   - 新增 ParentOrganizationPickerView
   - 更新 iconForOrgType 和 colorForOrgType

2. **ViewModels/OrganizationsViewModel.swift**
   - 更新 createOrganization() 方法簽名
   - 支援父組織和課程資訊參數

## 🚀 後續優化建議

### 短期（可選）

1. **組織列表樹狀顯示**
   - 在 OrganizationsView 中顯示組織層級
   - 使用縮排表示父子關係
   - 可展開/收合子組織

2. **組織詳情頁面增強**
   - 顯示子組織列表
   - 顯示麵包屑導航（學校 > 系所 > 課程）
   - 快速創建子組織按鈕

3. **課程詳情專屬頁面**
   - 顯示課程資訊（學分、代碼、學期）
   - 顯示選課人數統計
   - 課程時間表視圖

### 中期（建議）

1. **批次創建功能**
   - CSV 匯入課程資料
   - 一次創建多個課程
   - 範本下載功能

2. **組織轉移功能**
   - 將課程從一個系所轉移到另一個
   - 自動更新層級資訊

3. **搜索和過濾**
   - 按組織類型過濾
   - 按層級搜索（只看學校、只看課程）
   - 多條件組合搜索

## ✨ 總結

Phase 3 成功完成了 UI 層的更新，現在用戶可以：

✅ 選擇父組織創建子組織
✅ 系統自動限制合法的組織類型
✅ 為課程類型填寫專屬資訊
✅ 享受流暢的創建流程

整個組織層級架構系統（Phase 1 + Phase 2 + Phase 3）已經完整實現，可以支援真實的學校使用場景！
