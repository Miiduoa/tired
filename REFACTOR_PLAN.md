# 課程架構重構計劃

## 📋 重構目標

將專案的組織架構從**複雜的層級組織模型**重構為**以課程為核心的 LMS 架構**，參考 TronClass、Moodle 等成熟學習管理系統的設計理念。

## 🎯 核心改變

### 1. **架構簡化**

#### 舊架構（複雜）
```
Organization (type: school/department/course/club/company...)
  ├── parentOrganizationId
  ├── rootOrganizationId
  ├── organizationPath: [String]
  ├── level: Int
  └── courseInfo: CourseInfo?  // 只有 type=course 才有

Membership (用戶 ↔ 組織)
  ├── roleIds: [String]  // 動態角色
  └── 複雜的權限繼承邏輯
```

**問題：**
- ❌ 概念混亂：課程被當作組織的一種類型
- ❌ 過度工程：三層組織層級（學校→系所→課程）
- ❌ 維護困難：動態角色系統、權限繼承複雜
- ❌ 查詢低效：需要遞歸查詢父組織

#### 新架構（簡潔）
```
Course (課程是核心實體)
  ├── institutionId: String?  // 所屬機構（扁平）
  ├── department: String?     // 系所（標籤，非層級）
  └── 所有課程資訊直接存儲

Enrollment (用戶 ↔ 課程)
  ├── role: CourseRole  // 固定枚舉：teacher/ta/student/observer
  └── 權限直接綁定在角色上
```

**優勢：**
- ✅ 概念清晰：課程是獨立的一等公民
- ✅ 扁平架構：Institution → Courses（兩層）
- ✅ 簡單高效：固定角色、預定義權限
- ✅ 查詢快速：直接查詢課程即可

---

## 📦 新增模型

### 1. Course (課程模型)
**檔案：** `Models/Course.swift`

```swift
struct Course {
    // 基本資訊
    var name: String                // "資料結構與演算法"
    var code: String                // "CS101"
    var semester: String            // "2024春季"

    // 所屬機構（扁平關係）
    var institutionId: String?      // 所屬學校/機構
    var department: String?         // 系所（標籤）

    // 課程設定
    var credits: Int?               // 學分數
    var courseLevel: CourseLevel    // 課程級別
    var maxEnrollment: Int?         // 最大人數
    var isPublic: Bool              // 是否公開
    var isArchived: Bool            // 是否封存

    // 課程內容
    var syllabus: String?           // 課程大綱
    var schedule: [CourseSchedule]  // 上課時間

    // 統計
    var currentEnrollment: Int      // 目前選課人數
}
```

**特色：**
- 課程是獨立實體，不依賴組織層級
- 所有課程資訊集中管理
- 支援封存、公開/私密設定
- 內建學期、學年管理

### 2. Enrollment (選課記錄)
**檔案：** `Models/Enrollment.swift`

```swift
struct Enrollment {
    var userId: String
    var courseId: String
    var role: CourseRole            // teacher/ta/student/observer
    var status: EnrollmentStatus    // active/pending/dropped/completed

    // 成績與學習表現
    var finalGrade: Double?
    var attendanceRate: Double?
    var completedAssignments: Int

    // 個人化
    var isFavorite: Bool
    var notificationsEnabled: Bool
}
```

**特色：**
- 取代 Membership 在課程場景的使用
- 固定角色：teacher, ta, student, observer
- 內建成績、出席率追蹤
- 支援個人化設定

### 3. CourseRole (固定角色枚舉)
```swift
enum CourseRole {
    case teacher    // 完整權限
    case ta         // 協助教學、評分
    case student    // 基本學習權限
    case observer   // 只能查看

    var permissions: Set<CoursePermission> {
        // 權限預先定義在 enum 中
    }
}
```

**優勢：**
- ✅ 不需要資料庫存儲角色定義
- ✅ 權限檢查極快（編譯時確定）
- ✅ 無法意外修改或刪除角色
- ✅ 程式碼自文檔化

---

## 🔄 遷移策略

### 階段一：並行存在（目前）
1. ✅ 新增 `Course` 和 `Enrollment` 模型
2. ✅ 創建 `CourseService` 和 `EnrollmentService`
3. ✅ 保留舊的 `Organization` 和 `Membership`（用於社團、公司等其他組織）

### 階段二：更新 Task 模型
```swift
struct Task {
    // OLD: var sourceOrgId: String?
    // NEW:
    var sourceCourseId: String?     // 來自課程的任務
    var sourceOrgId: String?        // 來自其他組織的任務（保留）
}
```

### 階段三：UI 重構
1. 創建新的課程相關 Views
   - `CourseListView` - 我的課程列表
   - `CourseDetailView` - 課程詳情頁
   - `EnrollmentManagementView` - 選課管理
   - `CreateCourseView` - 建立課程

2. 保留組織相關 Views（用於社團等）

### 階段四：數據遷移（未來）
1. 將現有的 `Organization(type: .course)` 遷移到 `Course`
2. 將對應的 `Membership` 遷移到 `Enrollment`
3. 更新 Firestore 安全規則

---

## 📁 檔案結構

### 新增檔案
```
Models/
  ├── Course.swift          ✅ 已創建
  ├── Enrollment.swift      ✅ 已創建

Services/
  ├── CourseService.swift         // 待創建
  └── EnrollmentService.swift     // 待創建

ViewModels/
  ├── CourseListViewModel.swift   // 待創建
  └── CourseDetailViewModel.swift // 待創建

Views/Courses/
  ├── CourseListView.swift        // 待創建
  ├── CourseDetailView.swift      // 待創建
  ├── CreateCourseView.swift      // 待創建
  └── EnrollmentManagementView.swift  // 待創建
```

### 保留檔案（用於非課程組織）
```
Models/
  ├── Organization.swift    // 保留（社團、公司等）
  └── Membership.swift      // 保留

Services/
  └── OrganizationService.swift  // 保留但簡化

Views/Organizations/
  └── ...                   // 保留
```

---

## 🗃️ Firestore 集合結構

### 新集合
```
courses/{courseId}
  - Course 資料

enrollments/{enrollmentId}
  - userId, courseId, role, status, grades, etc.

courses/{courseId}/materials/{materialId}
  - 課程教材

courses/{courseId}/assignments/{assignmentId}
  - 作業

courses/{courseId}/announcements/{announcementId}
  - 公告
```

### 索引優化
```javascript
// enrollments collection
- userId
- courseId
- userId + courseId (複合索引)
- courseId + status
- userId + status

// courses collection
- institutionId
- semester
- isArchived
- createdByUserId
```

---

## 🎨 UI/UX 改進

### 課程列表
- 以學期分組顯示
- 支援篩選：進行中/已完成/已封存
- 顯示課程進度、成績預覽
- 快速操作：收藏、靜音通知

### 課程詳情
- Tab 分頁：公告、教材、作業、成績、成員
- 角色徽章清楚標示
- 快速存取課表、點名、評分

### 選課流程
- 教師建立課程 → 生成選課代碼
- 學生輸入代碼 → 申請加入（可設為自動批准）
- 教師審核 → 批准/拒絕

---

## ✅ 優勢總結

| 面向 | 舊架構 | 新架構 |
|------|--------|--------|
| **概念清晰度** | 組織概念過載 | 課程是核心，清楚明確 |
| **資料模型** | 3層組織 + 動態角色 | 2層扁平 + 固定角色 |
| **權限管理** | 複雜繼承和檢查 | 基於枚舉的簡單權限 |
| **查詢效率** | 遞歸查詢父組織 | 直接查詢課程 |
| **開發維護** | 需理解複雜邏輯 | 直觀易懂 |
| **擴展性** | 修改需動多處 | 單一職責，易擴展 |
| **用戶體驗** | 複雜的加入流程 | 簡單的選課流程 |

---

## 📝 下一步行動

- [x] 創建 Course 和 Enrollment 模型
- [ ] 實現 CourseService 和 EnrollmentService
- [ ] 創建課程相關 ViewModels
- [ ] 實現課程相關 Views
- [ ] 更新 Task 模型支援課程
- [ ] 更新 Firestore 安全規則
- [ ] 編寫測試
- [ ] 數據遷移腳本（未來）

---

## 🔗 參考資料

- TronClass - 成熟的 LMS 平台
- Moodle - 開源 LMS 標準
- Canvas LMS - 現代化設計
- Google Classroom - 簡潔的課程模型
