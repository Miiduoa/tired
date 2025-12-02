# 課程系統快速開始指南

## 🚀 5 分鐘快速整合

### 步驟 1：添加課程入口到主導航（2 分鐘）

在你的主 TabView 或導航中添加課程入口：

```swift
// 在你的 MainTabView.swift 或類似文件中
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 你現有的 Tab...
            HomeView()
                .tabItem {
                    Label("首頁", systemImage: "house.fill")
                }
            
            // ✨ 新增：課程 Tab
            NavigationStack {
                CourseListView()
            }
            .tabItem {
                Label("課程", systemImage: "book.fill")
            }
            
            // 其他現有 Tab...
            TasksView()
                .tabItem {
                    Label("任務", systemImage: "checkmark.circle.fill")
                }
        }
    }
}
```

### 步驟 2：測試課程功能（3 分鐘）

#### 作為教師：
1. **打開 App** → 點擊「課程」Tab
2. **點擊 [+]** → 選擇「建立課程」
3. **填寫資訊**：
   ```
   課程名稱：資料結構與演算法
   課程代碼：CS101
   學期：2024春季（自動填入）
   學分：3
   ```
4. **點擊「建立」** → 課程創建成功
5. **查看選課代碼** → 進入課程詳情 → 在「簡介」Tab 看到選課代碼（如：AB12CD34）

#### 作為學生：
1. **打開 App** → 點擊「課程」Tab
2. **點擊 [+]** → 選擇「使用代碼加入」
3. **輸入代碼**：AB12CD34
4. **點擊「加入課程」** → 成功加入
5. **查看課程** → 返回課程列表，看到新課程

**完成！** 🎉 你已經成功整合課程系統！

---

## 📋 完整整合檢查清單

### 必要步驟
- [ ] 在主導航添加 CourseListView
- [ ] 確保 AuthService 可用
- [ ] 測試教師建課流程
- [ ] 測試學生選課流程
- [ ] 驗證權限控制

### 可選步驟
- [ ] 自訂課程顏色主題
- [ ] 整合到現有任務系統
- [ ] 添加通知功能
- [ ] 設置課程篩選預設值

---

## 💻 進階整合範例

### 範例 1：在首頁顯示課程快捷方式

```swift
// HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var courseViewModel = CourseListViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 歡迎區塊
                welcomeSection
                
                // 📚 我的課程區塊
                myCourseSection
                
                // 其他內容...
            }
            .padding()
        }
        .task {
            if let userId = authService.currentUserId {
                await courseViewModel.loadCourses(userId: userId)
                courseViewModel.selectedFilter = .active
            }
        }
    }
    
    private var myCourseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                Text("我的課程")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: CourseListView()) {
                    Text("查看全部")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            if courseViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if courseViewModel.filteredCourses.isEmpty {
                emptyCoursesView
            } else {
                // 顯示前 3 門課程
                ForEach(courseViewModel.filteredCourses.prefix(3)) { enrollment in
                    CourseQuickCard(enrollment: enrollment)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var emptyCoursesView: some View {
        VStack(spacing: 12) {
            Text("還沒有課程")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                NavigationLink(destination: CreateCourseView()) {
                    Label("建立課程", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                NavigationLink(destination: EnrollByCourseCodeView()) {
                    Label("加入課程", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// 緊湊的課程卡片
struct CourseQuickCard: View {
    let enrollment: EnrollmentWithCourse
    
    var body: some View {
        NavigationLink(destination: CourseDetailView(courseId: enrollment.course?.id ?? "")) {
            HStack(spacing: 12) {
                // 課程圖標
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: enrollment.course?.color ?? "#3B82F6") ?? .blue)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "book.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(enrollment.courseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(enrollment.courseCode) • \(enrollment.semester)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    RoleBadge(role: enrollment.enrollment.role)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
}
```

### 範例 2：將課程整合到任務系統

```swift
// CreateTaskView.swift
import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var selectedCourse: Course?
    @State private var dueDate = Date()
    
    @StateObject private var courseViewModel = CourseListViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("任務資訊") {
                    TextField("任務標題", text: $taskTitle)
                    
                    TextEditor(text: $taskDescription)
                        .frame(height: 100)
                }
                
                Section("相關課程") {
                    Picker("關聯課程", selection: $selectedCourse) {
                        Text("無關聯課程").tag(nil as Course?)
                        
                        ForEach(courseViewModel.filteredCourses) { enrollment in
                            if let course = enrollment.course {
                                HStack {
                                    Text(course.name)
                                    Text("(\(course.code))")
                                        .foregroundColor(.secondary)
                                }
                                .tag(course as Course?)
                            }
                        }
                    }
                    
                    if let course = selectedCourse {
                        HStack {
                            Text("課程")
                            Spacer()
                            Text(course.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("截止時間") {
                    DatePicker("截止日期", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task {
                            await createTask()
                        }
                    }
                    .disabled(taskTitle.isEmpty)
                }
            }
            .task {
                if let userId = authService.currentUserId {
                    await courseViewModel.loadCourses(userId: userId)
                }
            }
        }
    }
    
    private func createTask() async {
        guard let userId = authService.currentUserId else { return }
        
        let task = Task(
            userId: userId,
            sourceCourseId: selectedCourse?.id,  // ✨ 關聯到課程
            taskType: selectedCourse != nil ? .homework : .generic,
            title: taskTitle,
            description: taskDescription,
            category: .work,
            deadlineAt: dueDate
        )
        
        // 保存任務到 TaskService
        do {
            try await TaskService.shared.createTask(task)
            dismiss()
        } catch {
            print("建立任務失敗: \(error)")
        }
    }
}
```

### 範例 3：顯示課程相關的任務

```swift
// TaskListView.swift
import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var taskViewModel = TaskViewModel()
    
    var body: some View {
        List {
            // 按課程分組顯示任務
            ForEach(groupedByCourse.keys.sorted(), id: \.self) { courseId in
                Section(header: courseSectionHeader(courseId: courseId)) {
                    ForEach(groupedByCourse[courseId] ?? []) { task in
                        TaskRow(task: task)
                    }
                }
            }
        }
        .task {
            if let userId = authService.currentUserId {
                await taskViewModel.loadTasks(userId: userId)
            }
        }
    }
    
    // 按課程分組
    private var groupedByCourse: [String: [Task]] {
        Dictionary(grouping: taskViewModel.tasks.filter { $0.sourceCourseId != nil }) { task in
            task.sourceCourseId ?? "other"
        }
    }
    
    @ViewBuilder
    private func courseSectionHeader(courseId: String) -> some View {
        if courseId != "other" {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                Text(getCourseName(courseId: courseId))
                    .font(.headline)
            }
        } else {
            Text("其他任務")
                .font(.headline)
        }
    }
    
    private func getCourseName(courseId: String) -> String {
        // 從 CourseService 獲取課程名稱
        // 這裡簡化處理，實際應該快取課程資訊
        return "課程" // TODO: 實現課程名稱查詢
    }
}
```

---

## 🎨 自訂樣式

### 1. 自訂課程顏色

```swift
// 在建立課程時設定顏色
let course = Course(
    name: "資料結構",
    code: "CS101",
    semester: "2024春季",
    academicYear: "2024",
    color: "#3B82F6",  // 藍色
    createdByUserId: userId
)
```

### 2. 自訂角色徽章樣式

```swift
// 創建自己的角色徽章組件
struct MyRoleBadge: View {
    let role: CourseRole
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(.caption2)
            Text(role.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: role.color) ?? .blue,
                            Color(hex: role.color)?.opacity(0.7) ?? .blue.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .foregroundColor(.white)
        .shadow(radius: 2)
    }
}
```

---

## 🔍 測試清單

### 基本功能測試
- [ ] 教師可以建立課程
- [ ] 選課代碼正確生成（8位大寫）
- [ ] 學生可以使用代碼加入課程
- [ ] 課程出現在「我的課程」列表
- [ ] 可以查看課程詳情
- [ ] 課程篩選功能正常
- [ ] 搜索功能正常

### 權限測試
- [ ] 教師可以看到選課代碼
- [ ] 教師可以管理選課名單
- [ ] 教師可以變更學生角色
- [ ] 學生無法看到管理功能
- [ ] 學生可以退選課程
- [ ] 教師無法退選自己的課

### UI/UX 測試
- [ ] 課程卡片正確顯示
- [ ] 角色徽章正確顯示
- [ ] 統計資料正確
- [ ] 下拉刷新正常
- [ ] 滑動操作正常
- [ ] 錯誤提示清楚

---

## ⚠️ 常見問題

### Q: 找不到 CourseListView？
**A:** 確保你已經引入了正確的檔案：
```swift
import SwiftUI
// CourseListView 應該在 Views/Courses/ 目錄下
```

### Q: AuthService 報錯？
**A:** 確保在 App 入口設置了 EnvironmentObject：
```swift
@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(AuthService.shared)
        }
    }
}
```

### Q: 課程顏色不顯示？
**A:** 確保使用了 Color(hex:) extension（已在 CourseListView.swift 中提供）

### Q: 選課代碼無效？
**A:** 選課代碼會自動轉換為大寫，確保：
1. 代碼長度為 8 位
2. 課程未被封存
3. 未曾選過該課程

---

## 📞 需要幫助？

如果遇到問題：
1. 查看 `INTEGRATION_GUIDE.md` 了解詳細整合步驟
2. 查看 `COURSE_SYSTEM_SUMMARY.md` 了解完整架構
3. 查看程式碼註解獲取使用說明
4. 提交 GitHub Issue

---

## 🎊 下一步

完成基本整合後，你可以：
1. 實現作業提交系統
2. 實現成績管理系統
3. 添加課程公告功能
4. 整合日曆系統
5. 添加推送通知

參考 `INTEGRATION_GUIDE.md` 獲取更多進階功能範例！

---

**祝使用愉快！** 🚀

---

**最後更新：** 2025-12-01  
**版本：** 1.0.0
