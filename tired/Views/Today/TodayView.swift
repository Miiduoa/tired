import SwiftUI

struct TodayView: View {
    @EnvironmentObject var taskService: TaskService
    @State private var showQuickAdd = false

    var todayTasks: [Task] {
        taskService.getTodayTasks()
    }

    // 四區分類
    var overdueTasks: [Task] {
        let today = AppSession.shared.todayDate
        let tz = AppSession.shared.timeZone
        return todayTasks.filter { task in
            guard let deadline = task.deadlineAt else { return false }
            return deadline.isBefore(today, timeZone: tz)
        }
    }

    var deadlineTodayTasks: [Task] {
        let today = AppSession.shared.todayDate
        let tz = AppSession.shared.timeZone
        return todayTasks.filter { task in
            guard let deadline = task.deadlineAt else { return false }
            return deadline.isSameDay(as: today, timeZone: tz) && !deadline.isBefore(today, timeZone: tz)
        }
    }

    var postponedTasks: [Task] {
        let today = AppSession.shared.todayDate
        let tz = AppSession.shared.timeZone
        return todayTasks.filter { task in
            guard let planned = task.plannedWorkDate else { return false }
            let hasNoDeadlineIssue = task.deadlineAt == nil ||
                (!task.deadlineAt!.isBefore(today, timeZone: tz) &&
                 !task.deadlineAt!.isSameDay(as: today, timeZone: tz))
            return planned.isBefore(today, timeZone: tz) && hasNoDeadlineIssue
        }
    }

    var plannedTodayTasks: [Task] {
        let today = AppSession.shared.todayDate
        let tz = AppSession.shared.timeZone
        return todayTasks.filter { task in
            guard let planned = task.plannedWorkDate else { return false }
            let hasNoDeadlineIssue = task.deadlineAt == nil ||
                (!task.deadlineAt!.isBefore(today, timeZone: tz) &&
                 !task.deadlineAt!.isSameDay(as: today, timeZone: tz))
            let notPostponed = !planned.isBefore(today, timeZone: tz)
            return planned.isSameDay(as: today, timeZone: tz) && hasNoDeadlineIssue && notPostponed
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()

                if todayTasks.isEmpty {
                    EmptyTodayView()
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.spacing2) {
                            // 截止逾期
                            if !overdueTasks.isEmpty {
                                TaskSection(
                                    title: "截止逾期",
                                    icon: "exclamationmark.triangle.fill",
                                    color: AppTheme.errorColor,
                                    tasks: overdueTasks
                                )
                            }

                            // 今天到期
                            if !deadlineTodayTasks.isEmpty {
                                TaskSection(
                                    title: "今天到期",
                                    icon: "calendar.badge.exclamationmark",
                                    color: AppTheme.warningColor,
                                    tasks: deadlineTodayTasks
                                )
                            }

                            // 工作日延後
                            if !postponedTasks.isEmpty {
                                TaskSection(
                                    title: "工作日延後",
                                    icon: "clock.arrow.circlepath",
                                    color: AppTheme.textSecondary,
                                    tasks: postponedTasks
                                )
                            }

                            // 今天清單
                            if !plannedTodayTasks.isEmpty {
                                TaskSection(
                                    title: "今天清單",
                                    icon: "list.bullet",
                                    color: AppTheme.primaryColor,
                                    tasks: plannedTodayTasks
                                )
                            }
                        }
                        .padding(AppTheme.spacing2)
                    }
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus") {
                            showQuickAdd = true
                        }
                        .padding(AppTheme.spacing3)
                    }
                }
            }
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView()
            }
        }
    }
}

struct EmptyTodayView: View {
    var body: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.successColor)

                Text("🎉 今天清單是空的！")
                    .font(AppTheme.headline)

                Text("你可以試試：")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    NavigationLink(destination: Text("This Week")) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("從本週選幾個焦點")
                        }
                        .font(AppTheme.body)
                    }

                    NavigationLink(destination: Text("Backlog")) {
                        HStack {
                            Image(systemName: "tray")
                            Text("整理一下收集箱")
                        }
                        .font(AppTheme.body)
                    }
                }
                .padding(.top, AppTheme.spacing)
            }
        }
        .padding(AppTheme.spacing3)
    }
}

struct TaskSection: View {
    let title: String
    let icon: String
    let color: Color
    let tasks: [Task]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(AppTheme.subheadline)
                Spacer()
                Text("\(tasks.count)")
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            ForEach(tasks) { task in
                TaskCard(task: task)
            }
        }
    }
}

struct TaskCard: View {
    let task: Task
    @EnvironmentObject var taskService: TaskService

    var body: some View {
        GlassCard(padding: AppTheme.spacing2) {
            HStack(spacing: AppTheme.spacing2) {
                // Complete button
                Button(action: {
                    taskService.completeTask(task)
                }) {
                    Image(systemName: task.isTodayFocus ? "star.circle" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isTodayFocus ? AppTheme.accentColor : AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: AppTheme.spacing) {
                        // Category
                        Label(task.category.label, systemImage: task.category.icon)
                            .font(AppTheme.caption)
                            .foregroundColor(task.category.color)

                        // Priority
                        Text(task.priority.label)
                            .font(AppTheme.caption)
                            .foregroundColor(task.priority.color)

                        // Deadline
                        if let deadline = task.deadlineAt {
                            Text(DateUtils.formatDate(deadline))
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }

                Spacer()

                // Focus toggle
                Button(action: {
                    taskService.setTodayFocus(task, isFocus: !task.isTodayFocus)
                }) {
                    Image(systemName: task.isTodayFocus ? "star.fill" : "star")
                        .foregroundColor(task.isTodayFocus ? AppTheme.accentColor : AppTheme.textSecondary)
                }
            }
        }
    }
}

// Quick Add View
struct QuickAddView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskService: TaskService

    @State private var title = ""
    @State private var category: Task.TaskCategory = .personal
    @State private var priority: Task.Priority = .P2
    @State private var estimatedMin: Int = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("任務資訊") {
                    TextField("標題", text: $title)

                    Picker("分類", selection: $category) {
                        ForEach([Task.TaskCategory.school, .work, .personal, .other], id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }

                    Picker("優先度", selection: $priority) {
                        ForEach([Task.Priority.P0, .P1, .P2, .P3], id: \.self) { pri in
                            Text(pri.label).tag(pri)
                        }
                    }

                    Stepper("預估時間：\(estimatedMin) 分鐘", value: $estimatedMin, in: 15...240, step: 15)
                }
            }
            .navigationTitle("快速新增")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        guard let userId = taskService.userProfile?.userId else { return }

                        let task = Task(
                            userId: userId,
                            title: title,
                            category: category,
                            priority: priority
                        )
                        taskService.createTask(task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
