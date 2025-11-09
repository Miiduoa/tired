import SwiftUI

struct BacklogView: View {
    @EnvironmentObject var taskService: TaskService
    @State private var showQuickAdd = false
    @State private var filterCategory: Task.TaskCategory?
    @State private var filterPriority: Task.Priority?
    @State private var showInboxOnly = false

    var filteredTasks: [Task] {
        var tasks = taskService.getBacklogTasks()

        if let category = filterCategory {
            tasks = tasks.filter { $0.category == category }
        }

        if let priority = filterPriority {
            tasks = tasks.filter { $0.priority == priority }
        }

        if showInboxOnly {
            tasks = tasks.filter { $0.isInbox }
        }

        return tasks
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 過濾器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacing) {
                            FilterChip(
                                title: "收集箱",
                                isSelected: showInboxOnly
                            ) {
                                showInboxOnly.toggle()
                            }

                            ForEach([Task.TaskCategory.school, .work, .personal, .other], id: \.self) { cat in
                                FilterChip(
                                    title: cat.label,
                                    isSelected: filterCategory == cat
                                ) {
                                    filterCategory = filterCategory == cat ? nil : cat
                                }
                            }

                            ForEach([Task.Priority.P0, .P1, .P2, .P3], id: \.self) { pri in
                                FilterChip(
                                    title: pri.label,
                                    isSelected: filterPriority == pri
                                ) {
                                    filterPriority = filterPriority == pri ? nil : pri
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.spacing2)
                        .padding(.vertical, AppTheme.spacing)
                    }
                    .background(AppTheme.thinMaterial)

                    // 任務列表
                    if filteredTasks.isEmpty {
                        EmptyBacklogView(hasFilters: filterCategory != nil || filterPriority != nil || showInboxOnly)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.spacing) {
                                ForEach(filteredTasks) { task in
                                    BacklogTaskCard(task: task)
                                }
                            }
                            .padding(AppTheme.spacing2)
                        }
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
            .navigationTitle("Backlog")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.caption)
                .padding(.horizontal, AppTheme.spacing2)
                .padding(.vertical, AppTheme.spacing)
                .background(isSelected ? AppTheme.primaryColor : AppTheme.backgroundSecondary)
                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                .clipShape(Capsule())
        }
    }
}

struct EmptyBacklogView: View {
    let hasFilters: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacing2) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textSecondary)

            if hasFilters {
                Text("沒有符合條件的任務")
                    .font(AppTheme.headline)
                Text("試試調整過濾條件")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textSecondary)
            } else {
                Text("Backlog 是空的")
                    .font(AppTheme.headline)
                Text("所有任務都已經安排好了！")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.spacing3)
    }
}

struct BacklogTaskCard: View {
    let task: Task
    @EnvironmentObject var taskService: TaskService
    @State private var showActions = false

    var body: some View {
        GlassCard(padding: AppTheme.spacing2) {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: AppTheme.spacing) {
                            Label(task.category.label, systemImage: task.category.icon)
                                .font(AppTheme.caption)
                                .foregroundColor(task.category.color)

                            Text(task.priority.label)
                                .font(AppTheme.caption)
                                .foregroundColor(task.priority.color)

                            if task.isInbox {
                                Text("收集箱")
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.accentColor)
                            }
                        }
                    }

                    Spacer()

                    Button(action: { showActions = true }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .confirmationDialog("任務操作", isPresented: $showActions) {
            Button("排到今天") {
                taskService.setPlannedDate(task, date: AppSession.shared.todayDate, isManual: true)
            }
            Button("排到明天") {
                let tomorrow = DateUtils.addDays(AppSession.shared.todayDate, 1)
                taskService.setPlannedDate(task, date: tomorrow, isManual: true)
            }
            Button("設為焦點") {
                taskService.setTodayFocus(task, isFocus: true)
            }
            Button("完成") {
                taskService.completeTask(task)
            }
            Button("不做") {
                taskService.skipTask(task)
            }
            Button("取消", role: .cancel) {}
        }
    }
}
