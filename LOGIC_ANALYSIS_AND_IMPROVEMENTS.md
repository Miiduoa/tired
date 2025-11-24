# Tired App - 逻辑分析与改进建议报告

**报告日期**: 2025-11-24
**分析对象**: Tired iOS 多身份任务管理应用
**当前版本**: 功能完整版

---

## 📋 目录

1. [核心业务逻辑问题](#核心业务逻辑问题)
2. [缺失的关键功能](#缺失的关键功能)
3. [真实使用场景分析](#真实使用场景分析)
4. [改进方案详解](#改进方案详解)
5. [新增功能详细设计](#新增功能详细设计)
6. [优先级建议](#优先级建议)

---

## 核心业务逻辑问题

### 🔴 问题 1: 自动排程算法缺陷

**位置**: `Utils/AutoPlanService.swift: line 36-117`

**问题描述**:

自动排程算法在计算每日容量时存在多个问题：

```swift
// ❌ 问题代码 (line 61-68)
for task in tasks {
    guard let planned = task.plannedDate else { continue }
    let dayIndex = ...
    if dayIndex >= 0 && dayIndex < 7 {
        dayMinutes[dayIndex] += task.estimatedMinutes ?? 0  // ❌ 包含了已完成任务
    }
}
```

**具体缺陷**:

1. **已完成任务被计入容量**: `dayMinutes` 统计中没有过滤 `isDone == false`，导致已完成的任务仍占用容量
2. **没有考虑优先级**: 任务按 deadline 排序，但高优先级但 deadline 远的任务应该更早排程
3. **工作日逻辑硬编码**: 第 89 行假设周一-周五是工作日，不支持用户自定义工作日
4. **没有考虑跨越多天的任务**: 长期项目（如需要3天完成）的分配策略不明确

**影响**:

- 自动排程后容量计算不准确
- 用户可能被排程过载
- 优先级概念被忽视

**修复方案**:

```swift
// ✅ 改进方案
// 1. 过滤已完成任务
let activeTasks = tasks.filter { !$0.isDone }

// 2. 考虑优先级排序
let candidates = tasks
    .filter { task in !task.isDone && !task.isDateLocked && task.plannedDate == nil }
    .sorted { t1, t2 in
        // 先按优先级，再按deadline
        if t1.priority.rawValue != t2.priority.rawValue {
            return t1.priority.hierarchyValue > t2.priority.hierarchyValue
        }
        // 优先级相同，按deadline
        if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
            return d1 < d2
        }
        return t1.deadlineAt != nil
    }

// 3. 支持用户自定义工作日配置
struct AutoPlanOptions {
    let weekdaysConfiguration: [Int]? // [1, 2, 3, 4, 5] = Monday to Friday, or [1, 2, 3, 4, 5, 6, 7] = all days
}
```

---

### 🔴 问题 2: Task 视图逻辑混乱（Deadline vs PlannedDate）

**位置**: `Models/Task.swift: line 124-136`, `Views/Tasks/TasksView.swift`

**问题描述**:

任务有两个日期字段，但逻辑不清：
- `deadlineAt`: 截止日期（任务必须完成的日期）
- `plannedDate`: 计划执行日期（用户计划何时做这个任务）

当前的 `isToday()` 实现:
```swift
func isToday() -> Bool {
    guard let planned = plannedDate else {
        guard let deadline = deadlineAt else { return false }
        return Calendar.current.isDateInToday(deadline)
    }
    return Calendar.current.isDateInToday(planned)
}
```

当前的 `isThisWeek()` 实现:
```swift
func isThisWeek() -> Bool {
    guard let planned = plannedDate else { return false }  // ❌ 完全忽视deadline
    return Calendar.current.isDate(planned, equalTo: Date(), toGranularity: .weekOfYear)
}
```

**具体缺陷**:

1. **周视图严重遗漏任务**: 如果任务有 deadline 在本周但没有排程，就不会在周视图中显示
2. **逻辑不一致**: `isToday()` 会回退到 deadline，但 `isThisWeek()` 不会
3. **真实场景冲突**: 用户可能有周五的 deadline，但还没有计划何时做，这个任务应该显示在"本周"视图中

**真实场景示例**:

```
周一 10:00 - 用户创建任务"完成报告"，deadline = 周五 17:00，没有排程日期
周二查看"本周"视图 - ❌ 看不到这个任务（因为plannedDate为nil）
周五 16:00 - 用户突然发现任务，才意识到只有1小时就deadline了
```

**修复方案**:

```swift
// ✅ 改进的isThisWeek()
func isThisWeek() -> Bool {
    let calendar = Calendar.current
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
        return false
    }

    // 检查是否有排程在本周
    if let planned = plannedDate,
       weekInterval.contains(planned) {
        return true
    }

    // 检查deadline是否在本周 ✅ 关键修复
    if let deadline = deadlineAt,
       weekInterval.contains(deadline) {
        return true
    }

    return false
}

// ✅ 新增方法：检查是否是"应该今天完成"的任务
var isUrgent: Bool {
    guard let deadline = deadlineAt else { return false }
    // 如果deadline在今天或更早，无论有没有排程都是紧急的
    return Calendar.current.isDateInToday(deadline) || deadline < Date()
}

// ✅ 改进的视图展示逻辑
// "今天"视图应该显示:
// 1. plannedDate = 今天的任务
// 2. deadline = 今天的任务 (无论是否排程)
// 3. 逾期的任务 (deadline < 今天)
```

---

### 🔴 问题 3: 多身份任务冲突未检测

**位置**: `ViewModels/TasksViewModel.swift`, `Models/Task.swift`

**问题描述**:

用户在多个组织中有不同身份，来自不同组织的任务可能发生时间冲突，但系统没有检测或警告。

**真实场景**:

```
用户身份：
- 学生 (School Organization)
- 实习生 (Company Organization)
- 社长 (Club Organization)

周三 14:00-16:00:
- 学校分配: "高数课程" (sourceOrgId = school_org)
- 公司分配: "团队会议" (sourceOrgId = company_org)
- 社团分配: "社员会议" (sourceOrgId = club_org)

结果: 三个任务同时进行，系统没有警告 ❌
```

**修复方案**:

```swift
// ✅ 新增冲突检测服务
class TaskConflictDetector {
    /// 检测给定时间范围内的任务冲突
    func detectConflicts(
        tasks: [Task],
        startDate: Date,
        duration: TimeInterval
    ) -> [TaskConflict] {
        let endDate = startDate.addingTimeInterval(duration)

        var conflicts: [TaskConflict] = []
        let overlappingTasks = tasks.filter { task in
            guard let planned = task.plannedDate,
                  let estimatedMinutes = task.estimatedMinutes else { return false }

            let taskEnd = planned.addingTimeInterval(TimeInterval(estimatedMinutes * 60))
            return !(taskEnd <= startDate || planned >= endDate) // 有重叠
        }

        if overlappingTasks.count > 1 {
            conflicts.append(TaskConflict(
                tasks: overlappingTasks,
                severity: overlappingTasks.count > 2 ? .severe : .warning
            ))
        }

        return conflicts
    }
}

// ✅ 自动排程时的冲突检测
func autoplanWeek(tasks: [Task], options: AutoPlanOptions) -> ([Task], [TaskConflict]) {
    let (updatedTasks, scheduledCount) = autoplanWeek(tasks: tasks, options: options)

    // 检测冲突
    let conflicts = TaskConflictDetector().detectConflicts(
        tasks: updatedTasks,
        startDate: options.weekStart,
        duration: 7 * 24 * 60 * 60
    )

    return (updatedTasks, conflicts)
}
```

---

### 🔴 问题 4: 任务完成后缺乏处理

**位置**: `ViewModels/TasksViewModel.swift`, `Services/TaskService.swift`

**问题描述**:

```swift
// ❌ 当前的任务完成逻辑
func toggleTaskDone(task: Task) {
    var updatedTask = task
    updatedTask.isDone.toggle()
    updatedTask.doneAt = updatedTask.isDone ? Date() : nil
    // ... 保存到Firebase
    // 就这样，没有其他逻辑
}
```

**问题**:

1. **容量未释放**: 完成任务后，占用的容量没有被释放，这会影响后续任务的排程
2. **没有激励反馈**: 用户完成任务后没有正反馈（经验值、徽章、统计等）
3. **没有链式完成**: 如果有后续任务依赖于这个任务，没有触发通知
4. **历史数据未利用**: 完成时间被记录但没有用于改进估计

**修复方案**:

```swift
// ✅ 完善的任务完成流程
func completeTask(task: Task) async throws {
    var updatedTask = task
    updatedTask.isDone = true
    updatedTask.doneAt = Date()

    // 1. 保存任务
    try await taskService.updateTask(updatedTask)

    // 2. 更新用户统计
    try await userService.updateTaskCompletionStats(
        userId: userId,
        taskId: task.id ?? "",
        originalEstimate: task.estimatedMinutes ?? 0,
        actualDuration: Date().timeIntervalSince(task.plannedDate ?? Date())
    )

    // 3. 检查并通知依赖任务 (新功能)
    let dependentTasks = try await taskService.fetchTasksDependentOn(taskId: task.id ?? "")
    for dependent in dependentTasks {
        // 通知用户，这个任务依赖的任务已完成
    }

    // 4. 触发激励系统 (新功能)
    let achievement = try await achievementService.checkAchievements(
        userId: userId,
        completedTaskCount: userProfile.completedTaskCount
    )
    if let newAchievement = achievement {
        showAchievementNotification(newAchievement)
    }

    // 5. 更新排程建议
    try await recomputeTaskEstimates()
}
```

---

### 🔴 问题 5: 日期锁定逻辑不清

**位置**: `Utils/AutoPlanService.swift: line 111`

**问题描述**:

```swift
updatedTasks[taskIndex].isDateLocked = false  // Autoplan should not lock the date
```

这个决定不符合UX最佳实践。用户可能想：

1. **自动排程后就锁定**: "我相信算法的排程，别再改了"
2. **不锁定，允许后续调整**: "这只是初始建议，我可能还要改"

目前的设计强制用户选项2，限制了灵活性。

**修复方案**:

```swift
// ✅ 给予用户选择权
struct AutoPlanOptions {
    let shouldLockDatesAfterAutoplan: Bool = false  // 默认不锁定，用户可选
    let shouldAskForConfirmation: Bool = true       // 自动排程前询问用户
}

// ✅ 改进的自动排程流程
@MainActor
func showAutoPlanConfirmation(proposedPlan: [Task]) async -> Bool {
    // 显示预览：哪些任务会被排程，排到哪些日期
    // 让用户选择"接受并锁定"或"接受不锁定"或"取消"
    return await confirmationViewController.show(proposedPlan)
}
```

---

### 🔴 问题 6: 权限检查不完整

**位置**: `Models/Task.swift`, `Services/PermissionService.swift`

**问题描述**:

任务有 `sourceOrgId` 标记来源组织，但：

```swift
// ❌ 当前没有权限检查
func toggleTaskDone(task: Task) {
    // 任何任务都可以标记完成，即使用户不属于源组织
}

// ❌ 当前无法验证用户是否可以访问来自特定组织的任务
if let sourceOrgId = task.sourceOrgId {
    // 应该检查：用户是否是这个组织的成员？
    // 但目前没有检查
}
```

**修复方案**:

```swift
// ✅ 添加权限检查
func canUserModifyTask(_ task: Task, userId: String) async throws -> Bool {
    // 如果是个人任务，只有创建者可以修改
    if task.sourceOrgId == nil {
        return task.userId == userId
    }

    // 如果是组织任务，检查用户权限
    let membership = try await orgService.fetchUserMembership(
        userId: userId,
        orgId: task.sourceOrgId!
    )

    // 检查权限：只有有权限的角色可以修改
    return permissionService.hasPermission(
        role: membership.roles,
        permission: .modifyOrgTask
    )
}

// ✅ 在View层调用
if try await canUserModifyTask(task, userId: userId) {
    updateTask()
} else {
    showError("您没有权限修改此任务")
}
```

---

## 缺失的关键功能

### 📌 缺失功能 1: 周期性/重复任务

**优先级**: ⭐⭐⭐⭐⭐ (最高)

**真实使用场景**:
- 每周一 09:00 - 周会
- 每天 21:00 - 复习
- 每个月 1 号 - 账目结算
- 工作日每天 - 晨会

**设计方案**:

```swift
// ✅ 新增 RecurringTask 数据模型
struct RecurringTask: Codable, Identifiable {
    @DocumentID var id: String?
    var baseTask: Task  // 基础任务模板

    // 重复规则
    var recurrenceRule: RecurrenceRule
    var recurrenceStartDate: Date
    var recurrenceEndDate: Date?  // nil = 无期限重复

    // 生成的任务实例
    var generatedTaskIds: [String] = []  // 已生成的Task ID列表
    var nextGenerationDate: Date  // 下一次应该生成任务的日期

    var createdAt: Date
    var updatedAt: Date
}

enum RecurrenceRule: Codable {
    case daily
    case weekdays  // 周一-周五
    case weekends  // 周六-周日
    case weekly(dayOfWeek: Int)  // 周几
    case biweekly(dayOfWeek: Int)  // 两周一次
    case monthly(dayOfMonth: Int)  // 每月X号
    case custom(cronExpression: String)  // Cron 表达式: "0 9 * * 1-5"
}

// ✅ 服务层
class RecurringTaskService {
    /// 生成新任务实例（每天凌晨运行）
    func generateTaskInstances(from recurringTask: RecurringTask) async throws -> [Task] {
        let generatedTasks = computeOccurrences(
            startDate: recurringTask.nextGenerationDate,
            endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            rule: recurringTask.recurrenceRule
        )

        var createdTasks: [Task] = []
        for occurrence in generatedTasks {
            var newTask = recurringTask.baseTask
            newTask.id = nil  // 新 ID
            newTask.plannedDate = occurrence
            newTask.deadlineAt = occurrence  // 重复任务的 deadline = 执行日期
            newTask.createdAt = Date()

            let savedTask = try await taskService.createTask(newTask)
            createdTasks.append(savedTask)
        }

        // 更新下一次生成日期
        try await update(recurringTask, nextGenerationDate: generatedTasks.last ?? Date())

        return createdTasks
    }

    /// 跳过某个周期的任务实例
    func skipOccurrence(date: Date, recurringTaskId: String) async throws {
        // 标记这个日期不生成任务
    }

    /// 修改整个系列的任务
    func updateSeries(recurringTaskId: String, newTask: Task) async throws {
        // 更新所有未来的生成的任务
    }
}

// ✅ 视图层交互
struct CreateRecurringTaskView: View {
    @State var baseTask: Task
    @State var recurrenceRule: RecurrenceRule = .daily
    @State var endDate: Date?

    var body: some View {
        Form {
            Section("任务基本信息") {
                TextField("任务标题", text: $baseTask.title)
                // ... 其他基本信息
            }

            Section("重复规则") {
                Picker("重复频率", selection: $recurrenceRule) {
                    Text("每天").tag(RecurrenceRule.daily)
                    Text("工作日").tag(RecurrenceRule.weekdays)
                    Text("周末").tag(RecurrenceRule.weekends)
                    Text("每周 Monday").tag(RecurrenceRule.weekly(dayOfWeek: 2))
                    Text("每月 1 号").tag(RecurrenceRule.monthly(dayOfMonth: 1))
                }

                Toggle("设置结束日期", isOn: .constant(endDate != nil))
                if endDate != nil {
                    DatePicker("重复至", selection: $endDate ?? Date())
                }
            }
        }
    }
}
```

---

### 📌 缺失功能 2: 任务依赖/前置条件

**优先级**: ⭐⭐⭐⭐ (高)

**真实使用场景**:
- 不能开始"编写代码"直到"需求分析"完成
- 不能提交报告直到"数据收集"完成
- 会议安排要在"确认与会者"完成后

**设计方案**:

```swift
// ✅ 新增字段到 Task 模型
struct Task: Codable, Identifiable {
    // ... 现有字段 ...

    /// 前置任务 ID 列表（这些任务必须先完成）
    var dependsOnTaskIds: [String] = []

    /// 阻塞任务 ID 列表（阻止这些任务开始）
    var blockingTaskIds: [String] = []
}

// ✅ 依赖关系服务
class TaskDependencyService {
    /// 检查任务是否可以开始
    func canStartTask(_ task: Task, allTasks: [Task]) -> Bool {
        for dependencyId in task.dependsOnTaskIds {
            guard let dependency = allTasks.first(where: { $0.id == dependencyId }) else {
                continue  // 依赖任务不存在
            }

            if !dependency.isDone {
                return false  // 依赖任务未完成
            }
        }
        return true
    }

    /// 获取任务的依赖链（递归）
    func getDependencyChain(_ taskId: String, allTasks: [Task]) -> [Task] {
        guard let task = allTasks.first(where: { $0.id == taskId }) else { return [] }

        var chain = [task]
        for depId in task.dependsOnTaskIds {
            chain.append(contentsOf: getDependencyChain(depId, allTasks: allTasks))
        }
        return chain
    }

    /// 自动排程时，尊重依赖关系
    func autoplanWithDependencies(
        tasks: [Task],
        options: AutoPlanService.AutoPlanOptions
    ) -> [Task] {
        // 按依赖关系排序任务，确保依赖的任务先排程
        let sortedTasks = topologicalSort(tasks)

        // 然后运行正常的自动排程
        return normalAutoplan(sortedTasks, options: options)
    }
}

// ✅ UI 显示依赖关系
struct TaskDetailView: View {
    let task: Task
    @StateObject private var viewModel = TaskDetailViewModel()

    var body: some View {
        VStack {
            // ... 任务基本信息 ...

            if !task.dependsOnTaskIds.isEmpty {
                Section("📋 前置任务") {
                    ForEach(viewModel.dependencies) { depTask in
                        HStack {
                            Image(systemName: depTask.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(depTask.isDone ? .green : .orange)
                            Text(depTask.title)
                            Spacer()
                            if !depTask.isDone {
                                Text("未完成")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            if !viewModel.blockingTasks.isEmpty {
                Section("🚫 阻塞任务") {
                    ForEach(viewModel.blockingTasks) { task in
                        Text(task.title)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}
```

---

### 📌 缺失功能 3: 时间块/日程锁定

**优先级**: ⭐⭐⭐⭐

**真实使用场景**:
- 预留午餐时间 12:00-13:00，任何任务都不能排进去
- 运动时间 18:00-19:00，需要保留
- 深度工作时间 09:00-12:00，只安排重要任务

**设计方案**:

```swift
// ✅ 新增 TimeBlock 模型
struct TimeBlock: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String

    let title: String  // "午餐", "运动", "深度工作"
    let color: String?

    /// 重复规则
    let recurrenceRule: RecurrenceRule?  // nil = 一次性

    /// 时间段
    let dayOfWeek: Int?  // 1-7: Monday-Sunday, nil = 每天都有
    let startTime: TimeOfDay  // 时:分
    let endTime: TimeOfDay    // 时:分
    let duration: Int  // 分钟数

    /// 这个时间块的性质
    let blockType: TimeBlockType

    var createdAt: Date
    var updatedAt: Date
}

enum TimeBlockType: String, Codable {
    case hard      // 硬阻止：任何任务都不能排进去
    case soft      // 软限制：尽量不排，但容量满时可以排
    case flexible  // 灵活：可以部分使用
}

// ✅ 自动排程时考虑时间块
class EnhancedAutoPlanService {
    func autoplanWeek(
        tasks: [Task],
        options: AutoPlanService.AutoPlanOptions,
        timeBlocks: [TimeBlock]  // 新参数
    ) -> [Task] {
        // 为每天构建"可用时间段"列表
        let availableSlots = computeAvailableTimeSlots(
            for: options.weekStart,
            given: timeBlocks
        )

        // 在可用时间段内排程任务
        return allocateTasksToAvailableSlots(
            tasks: tasks,
            availableSlots: availableSlots,
            capacity: options.dailyCapacityMinutes
        )
    }

    private func computeAvailableTimeSlots(
        for weekStart: Date,
        given timeBlocks: [TimeBlock]
    ) -> [Date: [TimeSlot]] {
        // 从 00:00 到 23:59 的时间段，减去 TimeBlocks
        var slots: [Date: [TimeSlot]] = [:]

        for dayOffset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!

            var availableForDay = [TimeSlot(start: "00:00", end: "23:59")]

            // 减去硬阻止的时间块
            for block in timeBlocks.filter({ $0.blockType == .hard }) {
                availableForDay = availableForDay.subtracting(block.toTimeSlot(for: day))
            }

            slots[day] = availableForDay
        }

        return slots
    }
}

// ✅ UI 编辑时间块
struct TimeBlockEditorView: View {
    @State var timeBlock: TimeBlock
    @State var isRecurring = false

    var body: some View {
        Form {
            Section("时间块信息") {
                TextField("名称", text: $timeBlock.title)
                    .placeholder("如：午餐、运动、深度工作")

                ColorPicker("颜色", selection: .constant(.blue))
            }

            Section("时间") {
                if isRecurring {
                    Picker("重复", selection: .constant("weekdays")) {
                        Text("每天").tag("daily")
                        Text("工作日").tag("weekdays")
                        Text("周末").tag("weekends")
                        Text("自定义").tag("custom")
                    }
                }

                DatePicker("开始时间", selection: .constant(Date()), displayedComponents: [.hourAndMinute])
                DatePicker("结束时间", selection: .constant(Date()), displayedComponents: [.hourAndMinute])
            }

            Section("性质") {
                Picker("类型", selection: $timeBlock.blockType) {
                    Text("硬阻止 (不能排任务)").tag(TimeBlockType.hard)
                    Text("软限制 (尽量避免)").tag(TimeBlockType.soft)
                    Text("灵活 (可部分使用)").tag(TimeBlockType.flexible)
                }
            }
        }
    }
}
```

---

### 📌 缺失功能 4: 任务子任务/里程碑

**优先级**: ⭐⭐⭐

**真实使用场景**:
```
大任务: "完成毕业设计项目"
├── 子任务 1: "确定选题和指导老师" (Milestone)
├── 子任务 2: "文献综述" (Milestone)
├── 子任务 3: "需求分析" (Milestone)
├── 子任务 4: "系统设计" (Milestone)
├── 子任务 5: "代码实现" (Milestone)
├── 子任务 6: "测试调试" (Milestone)
└── 子任务 7: "论文撰写和答辩" (Milestone)
```

**设计方案**:

```swift
// ✅ 新增字段到 Task
struct Task: Codable {
    // ... 现有字段 ...

    /// 父任务 ID（如果是子任务）
    var parentTaskId: String?

    /// 子任务 ID 列表
    var subtaskIds: [String] = []

    /// 是否是里程碑
    var isMilestone: Bool = false

    /// 子任务完成百分比 (0-100)
    var completionPercentage: Int? {
        guard !subtaskIds.isEmpty else { return nil }

        // 计算：已完成的子任务数 / 总子任务数 * 100
        let completedCount = subtaskIds.filter { id in
            // 在所有任务中查找这个子任务
            allTasks.first(where: { $0.id == id })?.isDone ?? false
        }.count

        return (completedCount * 100) / subtaskIds.count
    }
}

// ✅ 子任务管理服务
class SubtaskService {
    /// 向任务添加子任务
    func addSubtask(to parentTaskId: String, subtask: Task) async throws {
        var updatedParent = try await taskService.fetchTask(parentTaskId)
        var newSubtask = subtask
        newSubtask.parentTaskId = parentTaskId

        let savedSubtask = try await taskService.createTask(newSubtask)
        updatedParent.subtaskIds.append(savedSubtask.id ?? "")

        try await taskService.updateTask(updatedParent)
    }

    /// 自动计算父任务完成状态
    func updateParentProgress(childTaskId: String) async throws {
        guard let childTask = try await taskService.fetchTask(childTaskId),
              let parentId = childTask.parentTaskId else { return }

        let parentTask = try await taskService.fetchTask(parentId)
        let allChildren = try await taskService.fetchTasks(ids: parentTask.subtaskIds)

        let completedCount = allChildren.filter { $0.isDone }.count
        let progress = (completedCount * 100) / allChildren.count

        // 如果所有子任务都完成，自动标记父任务为完成
        if progress == 100 {
            var updatedParent = parentTask
            updatedParent.isDone = true
            updatedParent.doneAt = Date()
            try await taskService.updateTask(updatedParent)
        }
    }
}

// ✅ UI 展示子任务
struct TaskDetailView: View {
    let task: Task
    @StateObject private var viewModel = TaskDetailViewModel()

    var body: some View {
        VStack {
            // 基本信息...

            if !task.subtaskIds.isEmpty {
                Section("子任务 (\(viewModel.completedSubtasks)/\(task.subtaskIds.count))") {
                    ProgressView(value: Double(task.completionPercentage ?? 0) / 100)

                    ForEach(viewModel.subtasks) { subtask in
                        SubtaskRow(
                            task: subtask,
                            onToggle: { viewModel.toggleSubtask($0) }
                        )
                    }

                    Button(action: { viewModel.showAddSubtaskSheet = true }) {
                        Label("添加子任务", systemImage: "plus.circle")
                    }
                }
            }
        }
    }
}
```

---

### 📌 缺失功能 5: 任务标签和自定义分类

**优先级**: ⭐⭐⭐

**当前限制**: 只有 4 个固定分类 (学校、工作、社团、生活)

**真实需求**:
- 用户想用更灵活的标签：#紧急、#重要、#学习、#阅读、#运动、#副业等
- 想跨分类地筛选（如"所有#学习标签的任务"）

**设计方案**:

```swift
// ✅ 新增 Tag 模型
struct TaskTag: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let userId: String  // 用户自定义的标签

    var name: String       // "#紧急"
    var color: String?     // 十六进制颜色
    var icon: String?      // SF Symbol 图标
    var description: String?

    var createdAt: Date
}

// ✅ 扩展 Task 模型
struct Task: Codable {
    // ... 现有字段 ...

    /// 关联的标签 ID 列表
    var tagIds: [String] = []

    // 为了 UI 显示，保存标签对象（非 Codable）
    var tags: [TaskTag] = []
}

// ✅ 标签管理服务
class TaskTagService: ObservableObject {
    @Published var userTags: [TaskTag] = []

    func createTag(_ name: String, color: String?, icon: String? = nil) async throws {
        let tag = TaskTag(
            userId: userId,
            name: name,
            color: color,
            icon: icon
        )

        let saved = try await db.collection("taskTags").addDocument(from: tag)
        userTags.append(tag)
    }

    func addTagToTask(_ tagId: String, taskId: String) async throws {
        var task = try await taskService.fetchTask(taskId)
        if !task.tagIds.contains(tagId) {
            task.tagIds.append(tagId)
            try await taskService.updateTask(task)
        }
    }

    func searchTasksByTag(_ tagName: String) async throws -> [Task] {
        guard let tag = userTags.first(where: { $0.name == tagName }) else { return [] }

        return try await taskService.fetchUserTasks()
            .filter { $0.tagIds.contains(tag.id ?? "") }
    }
}

// ✅ UI: 管理标签
struct TaskTagManagerView: View {
    @StateObject private var tagService = TaskTagService()
    @State var newTagName = ""
    @State var selectedColor = Color.blue

    var body: some View {
        VStack {
            Section("我的标签") {
                ForEach(tagService.userTags) { tag in
                    HStack {
                        if let icon = tag.icon {
                            Image(systemName: icon)
                        } else {
                            Circle()
                                .fill(Color(tag.color ?? "#3B82F6"))
                                .frame(width: 12, height: 12)
                        }

                        Text(tag.name)
                        Spacer()

                        Button(role: .destructive, action: {
                            Task {
                                try await tagService.deleteTag(tag.id ?? "")
                            }
                        }) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Section("创建新标签") {
                HStack {
                    TextField("标签名称", text: $newTagName)
                    ColorPicker("颜色", selection: $selectedColor)

                    Button(action: {
                        Task {
                            try await tagService.createTag(
                                newTagName,
                                color: selectedColor.description
                            )
                            newTagName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
    }
}
```

---

### 📌 缺失功能 6: 任务提醒和通知系统

**优先级**: ⭐⭐⭐⭐⭐

**真实使用场景**:
- 任务开始前 30 分钟提醒
- 距离 deadline 还有 24 小时时提醒
- 任务逾期时提醒

**设计方案**:

```swift
// ✅ 新增提醒设置模型
struct TaskReminder: Codable, Identifiable {
    @DocumentID var id: String?
    let taskId: String
    let userId: String

    enum ReminderType: String, Codable {
        case beforeStart    // 任务开始前
        case beforeDeadline // deadline 前
        case atStartTime    // 任务开始时
        case custom         // 自定义时间
    }

    let type: ReminderType
    let minutesBefore: Int  // 提前多少分钟（用于 beforeStart 和 beforeDeadline）

    var isEnabled: Bool = true
    var notificationMethod: NotificationMethod = .push  // Push/邮件/App内通知

    var lastSentAt: Date?
    var createdAt: Date
}

enum NotificationMethod: String, Codable {
    case push      // Push notification
    case email     // 邮件
    case inApp     // App 内通知
    case all       // 全部
}

// ✅ 提醒服务
class TaskReminderService {
    /// 检查并发送应该触发的提醒
    @MainActor
    func checkAndSendReminders() async {
        let reminders = try? await fetchPendingReminders()

        for reminder in reminders ?? [] {
            guard let task = try? await taskService.fetchTask(reminder.taskId) else { continue }

            let shouldSend = shouldSendReminder(reminder, for: task)
            if shouldSend {
                await sendReminder(reminder, for: task)
                try? await updateReminderSentTime(reminder.id ?? "", sentAt: Date())
            }
        }
    }

    private func shouldSendReminder(_ reminder: TaskReminder, for task: Task) -> Bool {
        let now = Date()

        switch reminder.type {
        case .beforeStart:
            guard let plannedDate = task.plannedDate else { return false }
            let triggerTime = plannedDate.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
            return now >= triggerTime && (reminder.lastSentAt == nil || now.timeIntervalSince(reminder.lastSentAt!) > 300)

        case .beforeDeadline:
            guard let deadline = task.deadlineAt else { return false }
            let triggerTime = deadline.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
            return now >= triggerTime && !task.isDone

        case .atStartTime:
            guard let plannedDate = task.plannedDate else { return false }
            return Calendar.current.isDateInToday(plannedDate)

        case .custom:
            return false  // 由用户指定时间
        }
    }

    private func sendReminder(_ reminder: TaskReminder, for task: Task) async {
        let notificationContent = UNMutableNotificationContent()

        switch reminder.type {
        case .beforeStart:
            notificationContent.title = "📌 任务即将开始"
            notificationContent.body = "\(task.title) 将在 \(reminder.minutesBefore) 分钟后开始"

        case .beforeDeadline:
            notificationContent.title = "⏰ 任务即将截止"
            notificationContent.body = "\(task.title) 还有 \(reminder.minutesBefore) 分钟截止"

        case .atStartTime:
            notificationContent.title = "▶️ 任务现在开始"
            notificationContent.body = task.title

        case .custom:
            notificationContent.title = "📌 提醒"
            notificationContent.body = task.title
        }

        notificationContent.userInfo = ["taskId": task.id ?? ""]
        notificationContent.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id ?? UUID().uuidString, content: notificationContent, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// ✅ UI: 设置提醒
struct TaskReminderSettingsView: View {
    @StateObject private var reminderService = TaskReminderService()
    let task: Task
    @State var reminders: [TaskReminder] = []

    var body: some View {
        Section("任务提醒") {
            ForEach($reminders) { $reminder in
                HStack {
                    Picker("提醒类型", selection: $reminder.type) {
                        Text("开始前 15 分钟").tag(TaskReminder.ReminderType.beforeStart)
                        Text("截止前 1 小时").tag(TaskReminder.ReminderType.beforeDeadline)
                        Text("开始时").tag(TaskReminder.ReminderType.atStartTime)
                    }

                    Picker("通知方式", selection: $reminder.notificationMethod) {
                        Text("推送").tag(NotificationMethod.push)
                        Text("邮件").tag(NotificationMethod.email)
                        Text("App内").tag(NotificationMethod.inApp)
                    }

                    Toggle("", isOn: $reminder.isEnabled)
                }
            }

            Button(action: {
                let newReminder = TaskReminder(
                    taskId: task.id ?? "",
                    userId: userId,
                    type: .beforeStart,
                    minutesBefore: 15
                )
                reminders.append(newReminder)
            }) {
                Label("添加提醒", systemImage: "plus.circle")
            }
        }
    }
}
```

---

## 真实使用场景分析

### 场景 1: 考试周冲刺

**用户背景**: 大学生，有 5 门课的期末考试

**时间线**:
```
周一 (Day 1):
- 高数考试 (deadline 周三 14:00)
- 英语考试 (deadline 周四 15:00)
- 物理考试 (deadline 周五 10:00)
- 化学考试 (deadline 周五 14:00)
- 历史考试 (deadline 周六 09:00)

用户需要:
✅ 每门课自动分配复习时间，但要均衡
✅ 不能让多个复习任务同时进行（不可能完成）
❌ 当前系统: 自动排程可能会把所有复习都排在周一，导致无法完成
```

**当前问题**:
- AutoPlanService 不考虑任务难度分布
- 没有"冲突检测"告诉用户这个排程不可能完成

**改进方案**:
1. 实现"智能负载均衡" - 考虑任务复杂度分布
2. 冲突警告 - 用户能看到"您本周需要 25 小时，但只有 20 小时可用"
3. 交互式排程 - 允许用户手动调整冲突的任务

---

### 场景 2: 多身份工作日

**用户背景**: 在校学生 + 实习生 + 学生会主席

**冲突**:
```
周三 14:00-16:00:
- 学校: "计算机组成原理课"
- 公司: "项目 Standup 会议"
- 学生会: "活动筹备会议"

结果: 三个会议同时，系统没有警告 ❌
```

**当前问题**:
- 没有跨组织冲突检测
- 来自不同组织的任务被独立处理

**改进方案**:
1. 实现跨组织视图 - 看到所有身份的任务
2. 冲突检测 - "您在这个时间有 3 个冲突的任务"
3. 冲突解决建议 - "推荐将学生会会议改到周四"

---

### 场景 3: 突发任务重新排程

**用户背景**: 职场人士，有计划好的周任务

**时间线**:
```
周一上午: 用户已经自动排程好本周任务
周一中午: 突然收到紧急任务"完成财务审计"（deadline 周三）

需求:
- 插入这个任务到合适的位置
- 重新排程受影响的任务
- 告诉用户哪些任务需要移动

当前系统: ❌ 不支持"插入"，用户要手动调整
```

**改进方案**:
1. "插入任务"功能 - 自动重新排程
2. 变更通知 - 告知用户哪些任务被移动了

---

## 改进方案详解

### 方案 A: 优先修复的核心逻辑问题

**实施顺序**:

#### Step 1: 修复 isThisWeek() 逻辑 (优先级最高)
```
影响: 直接影响用户看到的任务列表
工作量: 小 (30 分钟)
收益: 高 - 用户不会遗漏 deadline 在本周的任务
```

**代码修改**:

文件: `Models/Task.swift`
```swift
// ❌ 旧逻辑
func isThisWeek() -> Bool {
    guard let planned = plannedDate else { return false }
    return Calendar.current.isDate(planned, equalTo: Date(), toGranularity: .weekOfYear)
}

// ✅ 改进逻辑
func isThisWeek() -> Bool {
    let calendar = Calendar.current
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
        return false
    }

    // 检查排期
    if let planned = plannedDate, weekInterval.contains(planned) {
        return true
    }

    // 检查 deadline ✅ 关键修复
    if let deadline = deadlineAt, weekInterval.contains(deadline) {
        return true
    }

    return false
}

// ✅ 新增方法：检查是否逾期
var isOverdueOrUrgent: Bool {
    if let deadline = deadlineAt, !isDone {
        return deadline <= Date()
    }
    return false
}
```

#### Step 2: 修复自动排程的已完成任务计算 (优先级高)
```
影响: 自动排程准确性
工作量: 小 (45 分钟)
收益: 高 - 排程不会因为已完成的旧任务而计算错误
```

**代码修改**:

文件: `Utils/AutoPlanService.swift`
```swift
// ❌ 旧代码 (line 61-68)
for task in tasks {
    guard let planned = task.plannedDate else { continue }
    let dayIndex = ...
    if dayIndex >= 0 && dayIndex < 7 {
        dayMinutes[dayIndex] += task.estimatedMinutes ?? 0  // ❌ 包含已完成任务
    }
}

// ✅ 改进代码
for task in tasks {
    guard let planned = task.plannedDate,
          !task.isDone else { continue }  // ✅ 只计算未完成任务

    let dayIndex = calendar.dateComponents([.day], from: calendar.startOfDay(for: options.weekStart), to: calendar.startOfDay(for: planned)).day ?? -1
    if dayIndex >= 0 && dayIndex < 7 {
        dayMinutes[dayIndex] += task.estimatedMinutes ?? 0
    }
}
```

#### Step 3: 添加优先级到自动排程 (优先级高)
```
影响: 排程的合理性
工作量: 中 (1.5 小时)
收益: 高 - 高优先级任务会优先排程
```

**代码修改**:

文件: `Utils/AutoPlanService.swift`
```swift
// ✅ 改进的候选任务排序
let candidates = tasks
    .filter { task in
        !task.isDone &&
        !task.isDateLocked &&
        task.plannedDate == nil
    }
    .sorted { t1, t2 in
        // 1. 按优先级排序 (high > medium > low)
        let priorityOrder: [TaskPriority] = [.high, .medium, .low]
        if let p1 = priorityOrder.firstIndex(of: t1.priority),
           let p2 = priorityOrder.firstIndex(of: t2.priority),
           p1 != p2 {
            return p1 < p2  // 优先级高的排前面
        }

        // 2. 优先级相同，按 deadline 排序
        if let d1 = t1.deadlineAt, let d2 = t2.deadlineAt {
            return d1 < d2
        }
        if t1.deadlineAt != nil { return true }
        if t2.deadlineAt != nil { return false }

        // 3. 都没有 deadline，按创建时间
        return t1.createdAt < t2.createdAt
    }
```

#### Step 4: 实现任务完成的激励反馈 (优先级中)
```
影响: 用户体验和激励
工作量: 中 (2 小时)
收益: 中 - 增加用户成就感和继续使用的动力
```

**代码修改**:

文件: `Services/TaskService.swift` 新增方法
```swift
// ✅ 任务完成处理
func completeTask(_ task: Task) async throws {
    var updatedTask = task
    updatedTask.isDone = true
    updatedTask.doneAt = Date()

    try await updateTask(updatedTask)

    // 保存完成统计（用于学习估计）
    try await saveTaskCompletionMetrics(
        taskId: task.id ?? "",
        estimatedMinutes: task.estimatedMinutes ?? 0,
        actualDurationMinutes: Int(Date().timeIntervalSince(task.plannedDate ?? Date()) / 60)
    )
}
```

---

### 方案 B: 实现高优先级新功能

**优先级顺序**:
1. **周期性任务** (3-4 天) - 真实场景需求最高
2. **任务提醒系统** (2-3 天) - 用户体验关键
3. **任务子任务** (2-3 天) - 大任务分解

---

## 新增功能详细设计

### 功能设计 1: 周期性任务

**数据模型**:

```swift
// Models/RecurringTask.swift

struct RecurringTask: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String

    // 基础任务模板
    var title: String
    var description: String?
    var category: TaskCategory
    var priority: TaskPriority
    var estimatedMinutes: Int?

    // 重复配置
    var recurrenceRule: RecurrenceRule
    var startDate: Date
    var endDate: Date?  // nil = 永远重复

    // 例外处理
    var skipDates: [Date] = []  // 跳过的日期
    var modifiedInstances: [Date: Task] = [:]  // 修改过的实例

    // 生成的任务
    var generatedInstanceIds: [String] = []  // 生成的 Task ID
    var lastGeneratedDate: Date?
    var nextGenerationDate: Date

    var createdAt: Date
    var updatedAt: Date
}

enum RecurrenceRule: Codable, Equatable {
    case daily
    case weekdays  // 周一-周五
    case weekends  // 周六-周日
    case weekly(dayOfWeek: Int)  // 1=周一, 7=周日
    case biweekly(dayOfWeek: Int)
    case monthly(dayOfMonth: Int)
    case custom(daysOfWeek: [Int])  // 多个特定日期
}
```

**服务层**:

```swift
// Services/RecurringTaskService.swift

class RecurringTaskService {
    private let db = FirebaseManager.shared.db
    private let taskService = TaskService()

    /// 获取用户的所有周期任务
    func fetchRecurringTasks(userId: String) -> AnyPublisher<[RecurringTask], Error> {
        let subject = PassthroughSubject<[RecurringTask], Error>()

        db.collection("recurringTasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("endDate", isGreaterThan: Date())
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                let recurringTasks = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: RecurringTask.self)
                } ?? []

                subject.send(recurringTasks)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 创建周期任务
    func createRecurringTask(_ recurringTask: RecurringTask) async throws {
        try await db.collection("recurringTasks").addDocument(from: recurringTask)

        // 立即生成第一批实例
        try await generateInstances(for: recurringTask)
    }

    /// 生成任务实例（每天晚上 23:59 运行）
    @MainActor
    func generateDueInstances() async throws {
        let allRecurringTasks = try await fetchAllRecurringTasks()

        for recurringTask in allRecurringTasks {
            if shouldGenerateToday(for: recurringTask) {
                try await generateInstances(for: recurringTask)
            }
        }
    }

    /// 为 recurring task 生成指定日期范围内的实例
    private func generateInstances(
        for recurringTask: RecurringTask,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws {
        let start = startDate ?? recurringTask.nextGenerationDate
        let end = endDate ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

        let occurrences = computeOccurrences(
            startDate: start,
            endDate: end,
            rule: recurringTask.recurrenceRule,
            skipDates: recurringTask.skipDates
        )

        var generatedIds: [String] = []

        for occurrence in occurrences {
            // 检查是否已有修改过的实例
            if let modifiedTask = recurringTask.modifiedInstances[occurrence] {
                let savedTask = try await taskService.updateTask(modifiedTask)
                generatedIds.append(savedTask.id ?? "")
                continue
            }

            // 创建新任务实例
            var newTask = Task(
                userId: recurringTask.userId,
                title: recurringTask.title,
                description: recurringTask.description,
                category: recurringTask.category,
                priority: recurringTask.priority,
                deadlineAt: occurrence,
                estimatedMinutes: recurringTask.estimatedMinutes,
                sourceType: .manual,
                createdAt: Date(),
                updatedAt: Date()
            )

            let savedTask = try await taskService.createTask(newTask)
            generatedIds.append(savedTask.id ?? "")
        }

        // 更新 recurring task 的生成记录
        var updated = recurringTask
        updated.generatedInstanceIds.append(contentsOf: generatedIds)
        updated.nextGenerationDate = Calendar.current.date(byAdding: .day, value: 30, to: end) ?? Date()

        try await db.collection("recurringTasks").document(recurringTask.id ?? "").setData(from: updated)
    }

    /// 计算重复规则对应的日期
    private func computeOccurrences(
        startDate: Date,
        endDate: Date,
        rule: RecurrenceRule,
        skipDates: [Date]
    ) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            let isMatch = matchesRule(currentDate, rule: rule)
            let isSkipped = skipDates.contains { calendar.isDate($0, inSameDayAs: currentDate) }

            if isMatch && !isSkipped {
                occurrences.append(currentDate)
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return occurrences
    }

    private func matchesRule(_ date: Date, rule: RecurrenceRule) -> Bool {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)

        switch rule {
        case .daily:
            return true

        case .weekdays:
            return (2...6).contains(dayOfWeek)  // 周一到周五

        case .weekends:
            return dayOfWeek == 1 || dayOfWeek == 7  // 周一 和 周日

        case .weekly(let targetDayOfWeek):
            return dayOfWeek == targetDayOfWeek

        case .biweekly(let targetDayOfWeek):
            let daysSinceStart = calendar.dateComponents([.day], from: date).day ?? 0
            return dayOfWeek == targetDayOfWeek && daysSinceStart % 14 == 0

        case .monthly(let targetDayOfMonth):
            return calendar.component(.day, from: date) == targetDayOfMonth

        case .custom(let daysOfWeek):
            return daysOfWeek.contains(dayOfWeek)
        }
    }

    /// 跳过某次重复实例
    func skipOccurrence(date: Date, recurringTaskId: String) async throws {
        guard var recurringTask = try await fetchRecurringTask(recurringTaskId) else { return }

        recurringTask.skipDates.append(date)

        try await db.collection("recurringTasks")
            .document(recurringTaskId)
            .updateData(["skipDates": recurringTask.skipDates])
    }

    /// 修改一个实例（只影响这一次，不影响后续）
    func modifyOccurrence(
        date: Date,
        recurringTaskId: String,
        updates: [String: Any]
    ) async throws {
        guard var recurringTask = try await fetchRecurringTask(recurringTaskId) else { return }

        // 获取或创建这一次的任务实例
        let taskForDate: Task

        if let existingTaskId = recurringTask.generatedInstanceIds.first(where: { taskId in
            guard let task = try? await taskService.fetchTask(taskId) else { return false }
            let calendar = Calendar.current
            return calendar.isDate(task.deadlineAt ?? Date(), inSameDayAs: date)
        }) {
            taskForDate = try await taskService.fetchTask(existingTaskId)
        } else {
            var newTask = Task(
                userId: recurringTask.userId,
                title: recurringTask.title,
                category: recurringTask.category,
                priority: recurringTask.priority,
                deadlineAt: date,
                estimatedMinutes: recurringTask.estimatedMinutes
            )
            taskForDate = try await taskService.createTask(newTask)
        }

        // 应用更新
        var modifiedTask = taskForDate
        if let newTitle = updates["title"] as? String {
            modifiedTask.title = newTitle
        }
        if let newEstimate = updates["estimatedMinutes"] as? Int {
            modifiedTask.estimatedMinutes = newEstimate
        }

        recurringTask.modifiedInstances[date] = modifiedTask

        try await db.collection("recurringTasks")
            .document(recurringTaskId)
            .setData(from: recurringTask)
    }
}
```

**UI 层**:

```swift
// Views/Tasks/CreateRecurringTaskView.swift

struct CreateRecurringTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateRecurringTaskViewModel()

    // 基本信息
    @State var title = ""
    @State var description = ""
    @State var category: TaskCategory = .personal
    @State var priority: TaskPriority = .medium
    @State var estimatedHours: Double = 1.0

    // 重复配置
    @State var recurrenceRule: RecurrenceRule = .daily
    @State var startDate = Date()
    @State var hasEndDate = false
    @State var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                Form {
                    // 基本信息部分
                    Section(header: Text("基本信息")) {
                        TextField("任务标题", text: $title)
                        TextField("描述（可选）", text: $description, axis: .vertical)
                            .lineLimit(2...4)

                        Picker("分类", selection: $category) {
                            ForEach(TaskCategory.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }

                        Picker("优先级", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }

                        HStack {
                            Text("预估时长")
                            Spacer()
                            Text("\(String(format: "%.1f", estimatedHours)) 小时")
                        }
                        Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                    }

                    // 重复配置部分
                    Section(header: Text("重复设置")) {
                        Picker("重复频率", selection: $recurrenceRule) {
                            Text("每天").tag(RecurrenceRule.daily)
                            Text("工作日 (周一-周五)").tag(RecurrenceRule.weekdays)
                            Text("周末 (周六-周日)").tag(RecurrenceRule.weekends)
                            Text("每周 Monday").tag(RecurrenceRule.weekly(dayOfWeek: 2))
                            Text("每月 1 号").tag(RecurrenceRule.monthly(dayOfMonth: 1))
                        }

                        DatePicker("开始日期", selection: $startDate, displayedComponents: [.date])

                        Toggle("设置结束日期", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("结束日期", selection: $endDate, displayedComponents: [.date])
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }

                        // 预览即将生成的实例
                        if let preview = viewModel.generatePreview(
                            rule: recurrenceRule,
                            startDate: startDate,
                            endDate: hasEndDate ? endDate : nil,
                            daysCount: 14
                        ) {
                            Section(header: Text("预览 (未来 14 天)")) {
                                ForEach(preview, id: \.self) { date in
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                        Text(date.formatted(date: .long, time: .omitted))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                .background(Color.clear)
            }
            .navigationTitle("创建周期任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { createRecurringTask() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createRecurringTask() {
        Task {
            let recurringTask = RecurringTask(
                userId: userId,
                title: title,
                description: description.isEmpty ? nil : description,
                category: category,
                priority: priority,
                estimatedMinutes: Int(estimatedHours * 60),
                recurrenceRule: recurrenceRule,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                nextGenerationDate: startDate
            )

            try await viewModel.createRecurringTask(recurringTask)
            dismiss()
        }
    }
}
```

---

## 优先级建议

### 🔴 P0 - 关键修复（立即修复，影响功能正确性）

1. **修复 isThisWeek() 逻辑** - 用户遗漏任务
   - 时间: 30 分钟
   - 影响: 高

2. **修复自动排程已完成任务计算** - 容量计算错误
   - 时间: 45 分钟
   - 影响: 高

3. **添加冲突检测** - 用户被过度排程
   - 时间: 2 小时
   - 影响: 高

### 🟠 P1 - 高优先级功能（本月实现）

1. **周期性任务** - 真实场景需求最高
   - 时间: 3-4 天
   - 收益: 非常高

2. **任务提醒系统** - 用户不会忘记任务
   - 时间: 2-3 天
   - 收益: 高

3. **子任务和里程碑** - 大任务分解
   - 时间: 2-3 天
   - 收益: 中高

### 🟡 P2 - 中优先级功能（季度实现）

1. **任务标签系统** - 灵活的分类
   - 时间: 2 天
   - 收益: 中

2. **任务依赖关系** - 工作流支持
   - 时间: 3-4 天
   - 收益: 中

3. **时间块管理** - 保护专注时间
   - 时间: 3 天
   - 收益: 中

### 🟢 P3 - 低优先级增强（按需实现）

1. **任务评论和协作** - 团队协作
   - 时间: 2-3 天
   - 收益: 低中

2. **任务历史和版本控制** - 审计和追踪
   - 时间: 2 天
   - 收益: 低

3. **任务导出和报告** - 数据分析
   - 时间: 2-3 天
   - 收益: 低

---

## 总结

您的 Tired App 已经拥有扎实的基础架构和核心功能。改进主要集中在：

1. **逻辑修复** - 3 个关键 bug 影响使用体验
2. **功能扩展** - 6 个新功能最符合真实使用需求
3. **用户体验** - 添加提醒、激励、冲突检测等

**建议的改进路线**:
- 第 1 周: 修复 P0 逻辑问题
- 第 2-3 周: 实现周期性任务和提醒系统
- 第 4-5 周: 子任务、标签和依赖关系

这样可以在 5 周内，将应用从"功能完整"升级到"生产级可靠"。

