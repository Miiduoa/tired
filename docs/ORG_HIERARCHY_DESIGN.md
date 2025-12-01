# 組織層級架構設計方案

## 📋 問題分析

目前的組織結構設計存在以下問題：

1. **缺少層級關係**：無法表達「學校 → 系所 → 課程」的層級結構
2. **課程屬性混亂**：課程相關屬性直接放在 Organization 中，但不是所有組織類型都需要
3. **角色定義不清**：沒有為不同組織類型定義標準角色模板
4. **權限繼承缺失**：上級組織的管理員無法管理下級組織

## 🎯 設計目標

以**學校場景**為例，建立完整的層級架構：

```
學校 (School)
├── 資訊管理系 (Department)
│   ├── 資料結構 (Course)
│   ├── 資料庫系統 (Course)
│   └── 演算法 (Course)
└── 企業管理系 (Department)
    ├── 管理學 (Course)
    └── 行銷學 (Course)
```

**角色設定範例：**
- **學校層級**：校長、副校長、行政人員、學生
- **系所層級**：系主任、教授、助教、系辦人員、學生
- **課程層級**：授課教師、助教、選課學生

## 🏗️ 技術方案

### 1. 增強 Organization 模型

```swift
struct Organization: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var type: OrgType
    var description: String?

    // ✨ 新增：層級關係
    var parentOrganizationId: String?    // 父組織 ID
    var rootOrganizationId: String?      // 根組織 ID（學校）
    var organizationPath: [String]?      // 組織路徑 [schoolId, deptId, courseId]
    var level: Int?                      // 組織層級 (0=學校, 1=系所, 2=課程)

    // ✨ 新增：課程專屬屬性（僅當 type == .course 時使用）
    var courseInfo: CourseInfo?

    // 原有屬性保持不變...
    var avatarUrl: String?
    var coverUrl: String?
    var isVerified: Bool
    var createdByUserId: String
    var createdAt: Date
    var updatedAt: Date
    var roles: [Role] = []
}

// 課程資訊獨立出來
struct CourseInfo: Codable {
    var courseCode: String              // 課程代碼 "CS101"
    var semester: String                // 學期 "2024-1"
    var academicYear: String            // 學年 "2024"
    var credits: Int                    // 學分數
    var syllabus: String?               // 課程大綱
    var courseLevel: String?            // 課程級別
    var prerequisites: [String]?        // 先修課程 ID
    var maxEnrollment: Int?             // 最大選課人數
    var currentEnrollment: Int          // 目前選課人數
}
```

### 2. 擴展 OrgType

```swift
enum OrgType: String, Codable, CaseIterable {
    case school         // 學校
    case department     // 系所/學院
    case course         // 課程
    case club           // 社團
    case company        // 公司
    case project        // 專案
    case other          // 其他

    // 是否支援子組織
    var canHaveChildren: Bool {
        switch self {
        case .school: return true       // 可包含 department
        case .department: return true   // 可包含 course
        case .course: return false      // 不能再包含子組織
        default: return false
        }
    }

    // 允許的子組織類型
    var allowedChildTypes: [OrgType] {
        switch self {
        case .school: return [.department, .club]
        case .department: return [.course]
        default: return []
        }
    }
}
```

### 3. 標準角色模板

```swift
enum StandardRoleTemplate {
    case school
    case department
    case course

    var roles: [(name: String, permissions: [OrgPermission])] {
        switch self {
        case .school:
            return [
                ("校長", OrgPermission.allCases),
                ("行政人員", [.viewContent, .editOrgInfo, .manageEvents]),
                ("學生", [.viewContent, .joinEvents, .comment])
            ]

        case .department:
            return [
                ("系主任", [.manageMembers, .changeRoles, .editOrgInfo, .manageApps, .createContent]),
                ("教授", [.viewContent, .createContent, .manageEvents]),
                ("助教", [.viewContent, .comment, .manageEvents]),
                ("學生", [.viewContent, .joinEvents, .comment])
            ]

        case .course:
            return [
                ("授課教師", [.manageMembers, .changeRoles, .createContent, .manageApps]),
                ("助教", [.viewContent, .createContent, .comment, .manageEvents]),
                ("學生", [.viewContent, .joinEvents, .comment, .submitAssignments])
            ]
        }
    }
}
```

### 4. 新增權限類型

```swift
enum OrgPermission: CaseIterable {
    // 現有權限...
    case deleteOrganization
    case transferOwnership
    case manageMembers
    case changeRoles
    // ...

    // ✨ 新增：課程相關權限
    case submitAssignments      // 繳交作業
    case gradeAssignments       // 批改作業
    case viewGrades            // 查看成績
    case manageGrades          // 管理成績
    case takeAttendance        // 點名
    case viewAttendance        // 查看出席紀錄

    // ✨ 新增：層級管理權限
    case manageChildOrgs       // 管理子組織
    case viewChildOrgs         // 查看子組織
}
```

## 🔄 使用流程範例

### 場景一：創建學校及其系所

```swift
// 1. 創建學校
let school = Organization(
    name: "國立XX大學",
    type: .school,
    level: 0,
    createdByUserId: currentUserId
)
let schoolId = try await orgService.createOrganization(school)

// 2. 創建系所
let department = Organization(
    name: "資訊管理系",
    type: .department,
    parentOrganizationId: schoolId,
    rootOrganizationId: schoolId,
    organizationPath: [schoolId],
    level: 1,
    createdByUserId: currentUserId
)
let deptId = try await orgService.createOrganization(department)

// 3. 創建課程
let courseInfo = CourseInfo(
    courseCode: "IM101",
    semester: "2024-1",
    academicYear: "2024",
    credits: 3,
    maxEnrollment: 60,
    currentEnrollment: 0
)
let course = Organization(
    name: "資料結構",
    type: .course,
    parentOrganizationId: deptId,
    rootOrganizationId: schoolId,
    organizationPath: [schoolId, deptId],
    level: 2,
    courseInfo: courseInfo,
    createdByUserId: currentUserId
)
let courseId = try await orgService.createOrganization(course)
```

### 場景二：用戶以不同角色瀏覽

```swift
// 學生登入後
let studentMemberships = try await orgService.fetchUserOrganizations(userId: studentId)

// 顯示組織結構
for membership in studentMemberships {
    if let org = membership.organization {
        switch org.type {
        case .school:
            print("🏫 \(org.name) - 學校")
        case .department:
            print("  📚 \(org.name) - 系所")
        case .course:
            print("    📖 \(org.name) - 課程")
        default:
            break
        }
    }
}

// 輸出範例：
// 🏫 國立XX大學 - 學校
//   📚 資訊管理系 - 系所
//     📖 資料結構 - 課程
//     📖 資料庫系統 - 課程
```

### 場景三：權限檢查（含層級繼承）

```swift
// 檢查用戶能否管理某個課程
func canManageCourse(userId: String, courseId: String) async throws -> Bool {
    let course = try await orgService.fetchOrganization(id: courseId)

    // 1. 檢查課程層級的權限
    if try await orgService.checkPermission(
        userId: userId,
        organizationId: courseId,
        permission: .manageMembers
    ) {
        return true
    }

    // 2. 檢查父組織（系所）的權限
    if let deptId = course.parentOrganizationId,
       try await orgService.checkPermission(
           userId: userId,
           organizationId: deptId,
           permission: .manageChildOrgs
       ) {
        return true
    }

    // 3. 檢查根組織（學校）的權限
    if let schoolId = course.rootOrganizationId,
       try await orgService.checkPermission(
           userId: userId,
           organizationId: schoolId,
           permission: .manageChildOrgs
       ) {
        return true
    }

    return false
}
```

## 📊 資料庫結構

### Firestore Collection 設計

```
organizations/
  {orgId}/
    - name: "國立XX大學"
    - type: "school"
    - parentOrganizationId: null
    - level: 0

    roles/ (subcollection)
      {roleId}/
        - name: "校長"
        - permissions: [...]

  {deptId}/
    - name: "資訊管理系"
    - type: "department"
    - parentOrganizationId: {schoolId}
    - rootOrganizationId: {schoolId}
    - level: 1

    roles/ (subcollection)
      {roleId}/
        - name: "系主任"
        - permissions: [...]

  {courseId}/
    - name: "資料結構"
    - type: "course"
    - parentOrganizationId: {deptId}
    - rootOrganizationId: {schoolId}
    - level: 2
    - courseInfo: {...}

    roles/ (subcollection)
      {roleId}/
        - name: "授課教師"
        - permissions: [...]

memberships/
  {membershipId}/
    - userId: {userId}
    - organizationId: {courseId}
    - roleIds: [{roleId}]
```

## 🔧 實施步驟

### Phase 1: 資料模型更新
1. 更新 `Organization.swift`，增加層級相關欄位
2. 創建 `CourseInfo.swift` 獨立模型
3. 擴展 `OrgType` 和 `OrgPermission`
4. 創建 `StandardRoleTemplate`

### Phase 2: Service 層更新
1. 更新 `OrganizationService.createOrganization()`
   - 驗證父子組織類型是否合法
   - 自動設置 level 和 organizationPath
   - 根據組織類型創建標準角色
2. 新增 `fetchChildOrganizations(parentId:)` 方法
3. 新增 `fetchOrganizationHierarchy(rootId:)` 方法
4. 更新權限檢查邏輯，支援層級繼承

### Phase 3: UI 更新
1. 創建組織樹狀視圖 `OrganizationTreeView`
2. 更新 `OrganizationDetailView`，顯示子組織列表
3. 創建課程專屬視圖 `CourseDetailView`
4. 優化角色選擇界面，根據組織類型過濾角色

### Phase 4: 資料遷移
1. 為現有組織資料補充 `level` 和 `parentOrganizationId`
2. 將課程相關欄位遷移到 `courseInfo` 物件
3. 為現有組織建立標準角色

## ⚠️ 注意事項

1. **向後兼容**：現有的組織（沒有 parentOrganizationId）應該視為根組織
2. **循環引用**：創建組織時必須檢查是否會造成循環引用
3. **刪除策略**：刪除父組織時，需要決定子組織的處理方式（級聯刪除 or 孤立）
4. **權限複雜度**：層級權限繼承可能導致權限檢查變慢，需要考慮快取策略

## 🎓 實際使用案例

**案例一：學生選課**
1. 學生瀏覽「資訊管理系」的課程列表
2. 點擊「資料結構」課程
3. 申請加入（創建 MembershipRequest，角色為「學生」）
4. 授課教師批准後，學生成為課程成員

**案例二：系主任管理**
1. 系主任登入，看到「資訊管理系」組織
2. 系主任擁有 `manageChildOrgs` 權限
3. 可以創建新課程、管理所有課程的成員
4. 可以查看所有課程的統計資料

**案例三：授課教師**
1. 教師被指派為「資料結構」的授課教師
2. 擁有該課程的 `manageMembers`、`gradeAssignments` 權限
3. 可以批改作業、管理學生名單、發布公告
4. 無法修改課程所屬的系所

## 🚀 未來擴展

1. **跨組織權限**：例如「兼任教師」可能在多個系所授課
2. **學分系統**：學生的總學分計算、畢業門檻檢查
3. **排課系統**：自動檢測課程時間衝突
4. **成績系統**：GPA 計算、成績單生成
5. **通知系統**：課程公告、作業提醒自動通知相關成員
