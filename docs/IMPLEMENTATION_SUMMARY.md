# 組織層級架構實施總結

## ✅ 已完成的任務

### Phase 1: 資料模型更新

#### 1. 創建 CourseInfo 模型
**文件**: `tired/tired/tired/Models/CourseInfo.swift`

獨立的課程資訊結構，包含：
- 課程代碼 (courseCode)
- 學期 (semester)
- 學年 (academicYear)
- 學分數 (credits)
- 課程大綱 (syllabus)
- 最大選課人數 (maxEnrollment)
- 目前選課人數 (currentEnrollment)
- 等等

#### 2. 更新 Organization 模型
**文件**: `tired/tired/tired/Models/Organization.swift`

新增層級結構欄位：
- `parentOrganizationId: String?` - 父組織 ID
- `rootOrganizationId: String?` - 根組織 ID
- `organizationPath: [String]?` - 組織路徑
- `level: Int?` - 組織層級 (0=根組織, 1=系所, 2=課程)
- `courseInfo: CourseInfo?` - 課程專屬資訊

移除舊的課程屬性，改用 CourseInfo 結構。

#### 3. 擴展 OrgType
**文件**: `tired/tired/tired/Models/DomainTypes.swift`

新增：
- `.course` - 課程類型
- `canHaveChildren` - 是否支援子組織
- `allowedChildTypes` - 允許的子組織類型
- `defaultLevel` - 預設層級深度

#### 4. 擴展 OrgPermission
**文件**: `tired/tired/tired/Models/DomainTypes.swift`

新增課程相關權限：
- `submitAssignments` - 繳交作業
- `gradeAssignments` - 批改作業
- `viewGrades` - 查看成績
- `manageGrades` - 管理成績
- `takeAttendance` - 點名
- `viewAttendance` - 查看出席紀錄

新增層級管理權限：
- `manageChildOrgs` - 管理子組織
- `viewChildOrgs` - 查看子組織
- `createChildOrgs` - 創建子組織

#### 5. 創建 StandardRoleTemplate
**文件**: `tired/tired/tired/Models/StandardRoleTemplate.swift`

提供不同組織類型的標準角色模板：
- **學校**: 擁有者、校長、行政人員、學生
- **系所**: 擁有者、系主任、教授、助教、學生
- **課程**: 擁有者、授課教師、助教、學生
- **公司**: 擁有者、管理員、員工、成員
- **社團**: 擁有者、社長、幹部、社員
- **專案**: 擁有者、專案經理、成員

### Phase 2: Service 層更新

#### 1. 更新 OrganizationService.createOrganization()
**文件**: `tired/tired/tired/Services/OrganizationService.swift`

新增功能：
- ✅ 驗證父子組織類型是否合法
- ✅ 自動設置 level 和 organizationPath
- ✅ 根據組織類型使用 StandardRoleTemplate 創建標準角色
- ✅ 驗證父組織是否允許該類型的子組織

#### 2. 新增查詢子組織方法
**文件**: `tired/tired/tired/Services/OrganizationService.swift`

新增方法：
- `fetchChildOrganizations(parentId:)` - 獲取指定組織的所有子組織
- `fetchOrganizationHierarchy(rootId:)` - 遞迴獲取完整組織樹

#### 3. 更新權限檢查邏輯
**文件**: `tired/tired/tired/Services/OrganizationService.swift`

增強 `checkPermission()` 方法：
- ✅ 檢查當前組織的直接權限
- ✅ 檢查父組織的 `manageChildOrgs` 權限（層級繼承）
- ✅ 檢查根組織的 `manageChildOrgs` 權限

新增方法：
- `checkPermissionForChildOrg(userId:childOrgId:permission:)` - 專門檢查子組織的管理權限

## 📊 架構示例

### 學校三層架構

```
🏫 國立XX大學 (School, Level 0)
  │
  ├── 📚 資訊管理系 (Department, Level 1)
  │   ├── 📖 資料結構 (Course, Level 2)
  │   ├── 📖 資料庫系統 (Course, Level 2)
  │   └── 📖 演算法 (Course, Level 2)
  │
  └── 📚 企業管理系 (Department, Level 1)
      ├── 📖 管理學 (Course, Level 2)
      └── 📖 行銷學 (Course, Level 2)
```

### 使用範例

```swift
// 1. 創建學校
let school = Organization(
    name: "國立XX大學",
    type: .school,
    createdByUserId: currentUserId
)
let schoolId = try await orgService.createOrganization(school)

// 2. 創建系所
let department = Organization(
    name: "資訊管理系",
    type: .department,
    parentOrganizationId: schoolId,
    createdByUserId: currentUserId
)
let deptId = try await orgService.createOrganization(department)
// 自動設置: level=1, rootOrganizationId=schoolId, organizationPath=[schoolId]

// 3. 創建課程
let courseInfo = CourseInfo(
    courseCode: "IM101",
    semester: "2024-1",
    academicYear: "2024",
    credits: 3,
    maxEnrollment: 60
)
let course = Organization(
    name: "資料結構",
    type: .course,
    parentOrganizationId: deptId,
    courseInfo: courseInfo,
    createdByUserId: currentUserId
)
let courseId = try await orgService.createOrganization(course)
// 自動設置: level=2, rootOrganizationId=schoolId, organizationPath=[schoolId, deptId]

// 4. 查詢子組織
let departments = try await orgService.fetchChildOrganizations(parentId: schoolId)
let courses = try await orgService.fetchChildOrganizations(parentId: deptId)

// 5. 權限檢查（含層級繼承）
// 系主任可以管理系所下的所有課程
let canManageCourse = try await orgService.checkPermission(
    userId: departmentHeadUserId,
    organizationId: courseId,
    permission: .manageMembers
)
// 返回 true，因為系主任在父組織（系所）擁有 manageChildOrgs 權限
```

## 🔐 權限繼承邏輯

### 範例：系主任管理課程

```
用戶角色：系主任（資訊管理系）

檢查權限：能否管理「資料結構」課程的成員？

步驟 1: 檢查課程層級
  ❌ 系主任不是「資料結構」課程的直接成員

步驟 2: 檢查父組織（資訊管理系）
  ✅ 系主任在「資訊管理系」擁有 manageChildOrgs 權限

結果: ✅ 允許管理
```

### 範例：學生權限

```
用戶角色：學生（選修「資料結構」課程）

檢查權限：能否批改作業？

步驟 1: 檢查課程層級
  ❌ 學生角色不包含 gradeAssignments 權限

步驟 2: 檢查父組織（資訊管理系）
  ❌ 學生不是系所成員或沒有 manageChildOrgs 權限

結果: ❌ 拒絕操作
```

## 📁 修改的文件清單

### 新增文件
1. `tired/tired/tired/Models/CourseInfo.swift` - 課程資訊模型
2. `tired/tired/tired/Models/StandardRoleTemplate.swift` - 標準角色模板
3. `docs/ORG_HIERARCHY_DESIGN.md` - 設計文檔
4. `docs/IMPLEMENTATION_SUMMARY.md` - 實施總結（本文件）

### 修改文件
1. `tired/tired/tired/Models/Organization.swift` - 增加層級欄位
2. `tired/tired/tired/Models/DomainTypes.swift` - 擴展 OrgType 和 OrgPermission
3. `tired/tired/tired/Services/OrganizationService.swift` - 更新創建和權限邏輯

## ⚠️ 重要注意事項

### 1. 向後兼容性
- 現有的組織（沒有 parentOrganizationId）會被視為根組織
- level、organizationPath 等欄位都是可選的 (Optional)
- 舊的創建方式仍然可用，只是不會建立層級關係

### 2. 數據遷移
現有的組織資料需要：
- 補充 level 欄位（根組織設為 0）
- 如果有課程屬性，需要遷移到 courseInfo 結構

建議的遷移腳本（待實施）：
```swift
// 為所有組織補充 level = 0（視為根組織）
// 將舊的課程欄位遷移到 courseInfo
```

### 3. Firestore 索引
需要在 Firebase Console 建立複合索引：
- `organizations` collection: `parentOrganizationId` (Ascending)
- 可能需要的複合索引: `(parentOrganizationId, type)`

### 4. UI 更新（下一步）
目前只完成了資料模型和 Service 層，UI 還需要更新：
- 創建組織時選擇父組織
- 顯示組織樹狀結構
- 角色選擇界面根據組織類型過濾

## 🎯 下一步建議

### Phase 3: UI 更新
1. **創建組織視圖**
   - 添加「父組織」選擇器
   - 根據父組織類型限制子組織類型
   - 課程類型顯示 CourseInfo 輸入欄位

2. **組織列表視圖**
   - 顯示組織樹狀結構
   - 可展開/收合子組織
   - 顯示層級深度（縮排）

3. **組織詳情視圖**
   - 顯示「子組織」標籤
   - 顯示父組織和根組織的麵包屑導航
   - 課程類型顯示 CourseInfo 詳情

4. **角色管理視圖**
   - 根據組織類型顯示標準角色
   - 新增課程相關權限的勾選

### Phase 4: 資料遷移
1. 創建遷移腳本
2. 為現有組織補充 level 欄位
3. 測試權限繼承邏輯

## 🐛 已知問題

暫無

## ✨ 功能亮點

1. **自動層級管理** - 創建子組織時自動設置 level 和路徑
2. **類型驗證** - 防止創建不合法的父子關係（如課程下不能再有子組織）
3. **權限繼承** - 父組織的管理員自動擁有子組織的管理權限
4. **標準角色模板** - 不同組織類型自動創建符合場景的角色
5. **靈活擴展** - 可以輕鬆添加新的組織類型和權限

## 🎓 使用場景覆蓋

✅ 學校 → 系所 → 課程 (教育場景)
✅ 公司 → 部門 → 專案 (企業場景)
✅ 社團 (扁平結構)
✅ 其他自定義組織

## 📝 總結

本次實施完成了組織層級架構的核心功能，包括：
- 完整的資料模型支援三層（或更多層）組織架構
- 標準角色模板系統，根據組織類型自動創建合適的角色
- 層級權限繼承機制，讓管理更加靈活
- 完整的 Service 層 API，支援創建、查詢和權限檢查

這個架構可以完美支援學校場景中「學校 → 系所 → 課程」的真實使用情境，同時也具備足夠的靈活性支援其他類型的組織結構。
