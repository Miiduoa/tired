# 課程系統整合指南

本指南說明如何在你的 App 中整合新的課程管理系統。

---

## 🚀 快速開始

### 1. 在主導航中添加課程入口

```swift
// 在你的主 TabView 或導航中添加
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 現有的 Tab...
            
            // 新增：課程 Tab
            NavigationStack {
                CourseListView()
            }
            .tabItem {
                Label("課程", systemImage: "book.fill")
            }
        }
    }
}
```

### 2. 基本使用流程

#### 教師建立課程

```swift
// 教師點擊「建立課程」
Button("建立課程") {
    showCreateCourse = true
}
.sheet(isPresented: $showCreateCourse) {
    CreateCourseView()
}

// CreateCourseView 會自動：
// 1. 生成選課代碼
// 2. 將建課者設為教師
// 3. 初始化課程統計
```

#### 學生加入課程

```swift
// 學生輸入選課代碼
Button("加入課程") {
    showEnrollByCourse = true
}
.sheet(isPresented: $showEnrollByCourse) {
    EnrollByCourseCodeView()
}

// EnrollByCourseCodeView 會自動：
// 1. 驗證代碼
// 2. 檢查是否已選課
// 3. 檢查人數限制
// 4. 創建選課記錄（學生角色）
```

---

## 📱 完整使用範例

### 範例 1：在首頁顯示我的課程

```swift
struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = CourseListViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 課程快速入口
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("我的課程")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        NavigationLink(destination: CourseListView()) {
                            Text("查看全部")
                                .font(.subheadline)
                        }
                    }
                    
                    // 顯示前3門進行中的課程
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        ForEach(viewModel.filteredCourses.prefix(3)) { enrollment in
                            CompactCourseCard(enrollment: enrollment)
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            if let userId = authService.currentUserId {
                await viewModel.loadCourses(userId: userId)
                viewModel.selectedFilter = .active
            }
        }
    }
}

// 緊湊的課程卡片
struct CompactCourseCard: View {
    let enrollment: EnrollmentWithCourse
    
    var body: some View {
        NavigationLink(destination: CourseDetailView(courseId: enrollment.course?.id ?? "")) {
            HStack {
                // 課程圖標
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "book.fill")
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(enrollment.courseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(enrollment.courseCode) • \(enrollment.semester)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}
```

### 範例 2：課程選單快捷操作

```swift
struct QuickActionsView: View {
    @State private var showCreateCourse = false
    @State private var showJoinCourse = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 建立課程
            Button(action: { showCreateCourse = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("建立新課程")
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // 加入課程
            Button(action: { showJoinCourse = true }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("使用代碼加入")
                    Spacer()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showCreateCourse) {
            CreateCourseView()
        }
        .sheet(isPresented: $showJoinCourse) {
            EnrollByCourseCodeView()
        }
    }
}
```

### 範例 3：在任務中關聯課程

```swift
struct CreateTaskView: View {
    @State private var taskTitle = ""
    @State private var selectedCourse: Course?
    @StateObject private var courseViewModel = CourseListViewModel()
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        Form {
            Section("任務資訊") {
                TextField("任務標題", text: $taskTitle)
            }
            
            Section("關聯課程") {
                Picker("課程", selection: $selectedCourse) {
                    Text("無").tag(nil as Course?)
                    
                    ForEach(courseViewModel.filteredCourses) { enrollment in
                        if let course = enrollment.course {
                            Text(course.name).tag(course as Course?)
                        }
                    }
                }
            }
        }
        .task {
            if let userId = authService.currentUserId {
                await courseViewModel.loadCourses(userId: userId)
            }
        }
    }
    
    func createTask() async {
        let task = Task(
            userId: authService.currentUserId ?? "",
            sourceCourseId: selectedCourse?.id,  // 關聯課程
            taskType: .homework,
            title: taskTitle,
            category: .work
        )
        
        // 保存任務...
    }
}
```

---

## 🔧 進階功能

### 1. 權限控制

```swift
// 在需要權限檢查的地方使用
struct CourseSettingsView: View {
    @StateObject private var viewModel: CourseDetailViewModel
    
    var body: some View {
        Form {
            // 只有教師可以編輯課程設定
            if viewModel.canEditSettings {
                Section("課程設定") {
                    // 設定選項...
                }
            }
            
            // 只有教學人員可以管理選課
            if viewModel.canManageEnrollment {
                Section("選課管理") {
                    Button("管理選課名單") {
                        // 開啟選課管理
                    }
                }
            }
            
            // 只有可以評分的人員可以看到成績管理
            if viewModel.canGrade {
                Section("成績管理") {
                    // 成績相關功能...
                }
            }
        }
    }
}
```

### 2. 實時更新

```swift
// 監聽課程變更
class MyCourseViewModel: ObservableObject {
    @Published var courses: [EnrollmentWithCourse] = []
    private var cancellables = Set<AnyCancellable>()
    
    func observeCourses(userId: String) {
        CourseService.shared.observeUserCourses(userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("錯誤: \(error)")
                    }
                },
                receiveValue: { [weak self] courses in
                    self?.courses = courses
                }
            )
            .store(in: &cancellables)
    }
}
```

### 3. 通知整合

```swift
// 當有新作業或公告時發送通知
extension CourseDetailViewModel {
    func sendAnnouncementNotification(
        courseId: String,
        title: String,
        body: String
    ) async {
        // 獲取所有學生
        let enrollments = try? await EnrollmentService.shared
            .fetchCourseEnrollments(courseId: courseId, role: .student)
        
        let userIds = enrollments?.map { $0.userId } ?? []
        
        // 發送通知給所有學生
        for userId in userIds {
            await NotificationService.shared.sendNotification(
                to: userId,
                title: title,
                body: body,
                data: ["courseId": courseId, "type": "announcement"]
            )
        }
    }
}
```

---

## 🎨 自訂樣式

### 1. 自訂課程卡片顏色

```swift
// 在 Course 模型中使用 color 屬性
let course = Course(
    name: "資料結構",
    code: "CS101",
    // ...
    color: "#3B82F6"  // 藍色
)

// 在 UI 中使用
RoundedRectangle(cornerRadius: 12)
    .fill(Color(hex: course.color ?? "#3B82F6") ?? .blue)
```

### 2. 自訂角色徽章

```swift
// 修改 RoleBadge 的樣式
struct CustomRoleBadge: View {
    let role: CourseRole
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(.caption2)
            Text(role.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: role.color) ?? .blue)
        )
        .foregroundColor(.white)
    }
}
```

---

## 📊 分析與統計

### 1. 追蹤課程活動

```swift
struct CourseAnalyticsView: View {
    let courseId: String
    @State private var statistics: CourseStatistics?
    
    var body: some View {
        VStack(spacing: 20) {
            if let stats = statistics {
                // 選課趨勢
                HStack {
                    VStack(alignment: .leading) {
                        Text("總選課人數")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(stats.totalEnrollments)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // 退選率
                    VStack(alignment: .trailing) {
                        Text("退選率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", stats.dropRate * 100))
                            .font(.title2)
                            .foregroundColor(stats.dropRate > 0.1 ? .red : .green)
                    }
                }
                
                // 角色分佈圖表
                // 可以使用 Charts framework (iOS 16+)
            }
        }
        .task {
            statistics = try? await CourseService.shared
                .fetchCourseStatistics(courseId: courseId)
        }
    }
}
```

---

## 🔐 安全性最佳實踐

### 1. 驗證用戶權限

```swift
// 在執行敏感操作前驗證權限
func deleteCourse(courseId: String) async throws {
    let userId = authService.currentUserId ?? ""
    
    // 檢查是否為課程建立者
    let course = try await CourseService.shared.fetchCourse(id: courseId)
    guard course.createdByUserId == userId else {
        throw AppError.unauthorized("只有建課教師可以刪除課程")
    }
    
    // 執行刪除
    try await CourseService.shared.deleteCourse(
        courseId: courseId,
        userId: userId
    )
}
```

### 2. 防止重複選課

```swift
// EnrollmentService 已內建檢查
func enrollInCourse(courseId: String, userId: String) async throws {
    // 自動檢查是否已選課
    // 如果已選課會拋出錯誤
    let enrollment = Enrollment(
        userId: userId,
        courseId: courseId,
        role: .student
    )
    
    try await EnrollmentService.shared.createEnrollment(enrollment)
}
```

---

## 🧪 測試

### 單元測試範例

```swift
import XCTest
@testable import YourApp

class CourseServiceTests: XCTestCase {
    var courseService: CourseService!
    
    override func setUp() {
        super.setUp()
        courseService = CourseService.shared
    }
    
    func testCreateCourse() async throws {
        let course = Course(
            name: "測試課程",
            code: "TEST101",
            semester: "2024-1",
            academicYear: "2024",
            createdByUserId: "test-user"
        )
        
        let courseId = try await courseService.createCourse(course)
        XCTAssertFalse(courseId.isEmpty)
        
        // 驗證課程已建立
        let fetchedCourse = try await courseService.fetchCourse(id: courseId)
        XCTAssertEqual(fetchedCourse.name, "測試課程")
    }
}
```

---

## 🐛 常見問題

### Q: 如何處理選課代碼過期？
A: 使用 `regenerateEnrollmentCode` 方法重新生成。

### Q: 如何批次匯入學生？
A: 使用 `EnrollmentManagementViewModel.importStudents`。

### Q: 可以設定課程的存取權限嗎？
A: 使用 `Course.isPublic` 屬性控制是否公開。

### Q: 如何實現課程複製？
```swift
func duplicateCourse(original: Course, newSemester: String) async throws -> String {
    var newCourse = original
    newCourse.id = nil  // 清除 ID
    newCourse.semester = newSemester
    newCourse.currentEnrollment = 0
    newCourse.createdAt = Date()
    
    return try await CourseService.shared.createCourse(newCourse)
}
```

---

## 📚 相關文檔

- [REFACTOR_PLAN.md](./REFACTOR_PLAN.md) - 架構設計說明
- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - 數據遷移指南
- [API 文檔](./API_DOCS.md) - 完整 API 參考

---

**最後更新：** 2025-12-01  
**版本：** 1.0.0
