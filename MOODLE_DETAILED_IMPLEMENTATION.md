# Moodle 級別精細功能實作計劃

## 🎯 目標
將 Tired App 升級為具備 Moodle 級別精細度的學習管理系統，同時保持 iOS 原生應用的優勢。

## 📊 Moodle 核心功能對照表

| Moodle 功能 | Tired App 現況 | 需要增強的部分 | 優先級 |
|------------|---------------|--------------|--------|
| **課程管理** | ✅ Organization 模型 | 課程代碼、學期、學分、時間表 | 🔴 高 |
| **作業系統** | ✅ Task 模型 | 作業提交、評分流程、截止日期管理 | 🔴 高 |
| **成績管理** | ❌ 無 | 完整成績系統（分數、評語、等級） | 🔴 高 |
| **討論區** | ✅ Post 模型 | 主題分類、置頂、已讀標記、訂閱 | 🟡 中 |
| **資源庫** | ✅ Resource 模型 | 文件上傳下載、版本控制、權限 | 🟡 中 |
| **行事曆** | ✅ CalendarService | 課程時間表整合、提醒系統 | 🟡 中 |
| **測驗系統** | ❌ 無 | 測驗創建、答題、自動評分 | 🟢 低 |
| **學習進度** | ❌ 無 | 進度追蹤、完成率統計 | 🟢 低 |
| **通知系統** | ✅ NotificationService | 作業提醒、成績通知、討論更新 | 🟡 中 |
| **使用者管理** | ✅ User + Membership | 角色權限細化、批量操作 | 🟡 中 |

## 🏗️ 實作架構

### Phase 1: 核心學習功能（2-3 週）

#### 1.1 成績管理系統（Gradebook）
**精細度要求：**
- ✅ 支援多種評分方式（分數、等級、通過/不通過）
- ✅ 評分權重計算
- ✅ 成績統計和分析
- ✅ 評語和反饋
- ✅ 成績歷史記錄
- ✅ 成績匯出功能

**實作內容：**
```
Models/
  - Grade.swift              # 成績模型
  - GradeItem.swift          # 成績項目（作業、測驗等）
  - GradeCategory.swift      # 成績分類（作業30%、測驗70%）
  
Services/
  - GradeService.swift       # 成績 CRUD、統計、計算
  
ViewModels/
  - GradeViewModel.swift     # 成績視圖邏輯
  
Views/
  - Grades/
    - GradeListView.swift    # 成績列表（按課程/組織）
    - GradeDetailView.swift  # 單項成績詳情
    - GradeStatisticsView.swift # 成績統計圖表
    - GradeExportView.swift  # 成績匯出
```

#### 1.2 課程/組織增強
**精細度要求：**
- ✅ 課程代碼、學期、學分
- ✅ 課程時間表（每週上課時間）
- ✅ 課程大綱（Syllabus）
- ✅ 課程進度追蹤
- ✅ 課程資源整合

**實作內容：**
```
Models/Organization.swift (擴展)
  - courseCode: String?
  - semester: String?
  - credits: Int?
  - schedule: [CourseSchedule]?
  - syllabus: String?
  
Models/
  - CourseSchedule.swift     # 課程時間表模型
  
Services/
  - CourseService.swift      # 課程管理服務
```

#### 1.3 作業系統增強
**精細度要求：**
- ✅ 作業提交功能（文件上傳）
- ✅ 提交狀態追蹤（未提交、已提交、已評分）
- ✅ 遲交處理
- ✅ 作業評分流程
- ✅ 作業反饋

**實作內容：**
```
Models/Task.swift (擴展)
  - submissionStatus: SubmissionStatus
  - submittedAt: Date?
  - submittedFiles: [FileAttachment]?
  - gradeId: String?         # 關聯到 Grade
  
Services/
  - AssignmentService.swift  # 作業提交服務
```

### Phase 2: 社群與協作功能（2-3 週）

#### 2.1 討論區增強
**精細度要求：**
- ✅ 主題分類和標籤
- ✅ 置頂功能
- ✅ 已讀/未讀標記
- ✅ 訂閱通知
- ✅ 搜尋功能
- ✅ 引用回覆

**實作內容：**
```
Models/Post.swift (擴展)
  - category: PostCategory?
  - isPinned: Bool
  - isAnnouncement: Bool
  - readByUserIds: [String]
  - subscribedUserIds: [String]
  
Services/
  - ForumService.swift      # 討論區增強服務
```

#### 2.2 資源庫完整功能
**精細度要求：**
- ✅ 文件上傳（多種格式）
- ✅ 文件下載
- ✅ 版本控制
- ✅ 文件預覽
- ✅ 權限控制
- ✅ 文件分類和標籤

**實作內容：**
```
Models/Resource.swift (已有，需增強)
  - version: Int
  - previousVersions: [String]?
  - downloadCount: Int
  - previewUrl: String?
  
Services/
  - ResourceService.swift    # 資源管理服務（擴展現有）
  - FileUploadService.swift  # 文件上傳服務
```

### Phase 3: 進階功能（3-4 週）

#### 3.1 測驗系統
**精細度要求：**
- ✅ 多種題型（選擇、填空、簡答）
- ✅ 自動評分
- ✅ 測驗時間限制
- ✅ 測驗結果分析
- ✅ 錯題回顧

**實作內容：**
```
Models/
  - Quiz.swift              # 測驗模型
  - Question.swift          # 題目模型
  - QuizAttempt.swift       # 測驗作答記錄
  - QuizAnswer.swift        # 答案模型
  
Services/
  - QuizService.swift       # 測驗服務
  - QuizGradingService.swift # 自動評分服務
```

#### 3.2 學習進度追蹤
**精細度要求：**
- ✅ 課程完成率
- ✅ 作業完成率
- ✅ 學習時間統計
- ✅ 進度視覺化
- ✅ 學習報告

**實作內容：**
```
Models/
  - LearningProgress.swift  # 學習進度模型
  
Services/
  - ProgressTrackingService.swift # 進度追蹤服務
  
Views/
  - Progress/
    - ProgressDashboardView.swift
    - ProgressChartView.swift
```

## 🔧 技術實作細節

### 資料庫結構設計

#### grades Collection
```typescript
grades/
  {gradeId}/
    taskId: string
    userId: string
    organizationId: string
    gradeItemId: string?      // 關聯到成績項目
    score: number?            // 分數（可選）
    maxScore: number          // 滿分
    grade: string?             // 等級（A, B, C, D, F）
    isPass: boolean?          // 通過/不通過
    feedback: string?         // 評語
    gradedBy: string          // 評分者
    gradedAt: timestamp
    createdAt: timestamp
    updatedAt: timestamp
```

#### gradeItems Collection
```typescript
gradeItems/
  {itemId}/
    organizationId: string
    name: string             // "作業1", "期中考"
    category: string?        // 成績分類
    weight: number           // 權重（0-100）
    maxScore: number
    dueDate: timestamp?
    createdAt: timestamp
```

#### courseSchedules Collection
```typescript
courseSchedules/
  {scheduleId}/
    organizationId: string
    dayOfWeek: number        // 1=週日, 2=週一, ...
    startTime: string        // "09:00"
    endTime: string         // "10:30"
    location: string?
    instructor: string?
    createdAt: timestamp
```

### 服務層設計

#### GradeService 核心方法
```swift
class GradeService {
    // 創建成績
    func createGrade(grade: Grade) async throws -> Grade
    
    // 更新成績
    func updateGrade(gradeId: String, score: Double?, feedback: String?) async throws
    
    // 獲取學生成績列表
    func getStudentGrades(userId: String, organizationId: String) async throws -> [Grade]
    
    // 獲取課程所有成績
    func getCourseGrades(organizationId: String) async throws -> [Grade]
    
    // 計算總成績
    func calculateFinalGrade(userId: String, organizationId: String) async throws -> GradeSummary
    
    // 成績統計
    func getGradeStatistics(organizationId: String) async throws -> GradeStatistics
}
```

## 📱 UI/UX 設計原則

### 1. 一致性
- 遵循 iOS Human Interface Guidelines
- 使用統一的設計系統（AppDesignSystem）
- 保持與現有 UI 風格一致

### 2. 可訪問性
- 支援 VoiceOver
- 支援動態字體大小
- 高對比度模式支援

### 3. 效能優化
- 使用 Combine 進行響應式更新
- 實作資料快取機制
- 優化圖片載入（使用 AsyncImage）

## ✅ 品質保證

### 1. 程式碼品質
- ✅ 完整的錯誤處理
- ✅ 單元測試覆蓋率 > 80%
- ✅ 程式碼註解和文檔
- ✅ 遵循 Swift API 設計準則

### 2. 功能完整性
- ✅ 所有 CRUD 操作
- ✅ 權限驗證
- ✅ 資料驗證
- ✅ 離線支援（Firestore 快取）

### 3. 使用者體驗
- ✅ 載入狀態指示
- ✅ 錯誤提示
- ✅ 空狀態處理
- ✅ 下拉刷新

## 🚀 實作時間表

### Week 1-2: 成績管理系統
- Day 1-3: 資料模型設計和實作
- Day 4-6: Service 層實作
- Day 7-10: ViewModel 和 View 實作
- Day 11-14: 測試和優化

### Week 3-4: 課程增強和作業系統
- Day 1-4: 課程模型擴展
- Day 5-8: 作業提交功能
- Day 9-12: UI 實作
- Day 13-14: 整合測試

### Week 5-6: 討論區和資源庫
- Day 1-4: 討論區增強
- Day 5-8: 資源庫完整功能
- Day 9-12: UI 實作
- Day 13-14: 測試和優化

### Week 7-8: 進階功能
- Day 1-5: 測驗系統
- Day 6-10: 學習進度追蹤
- Day 11-14: 整合和優化

## 📝 下一步行動

1. ✅ 開始實作成績管理系統（作為示範）
2. 根據用戶反饋調整功能優先順序
3. 逐步實作其他功能模組

