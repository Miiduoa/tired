import SwiftUI

@available(iOS 17.0, *)
struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var selectedTab: TaskTab = .today
    @State private var showingAddTask = false
    @State private var showingSortOptions = false

    enum TaskTab: String, CaseIterable {
        case today = "今天"
        case week = "本周"
        case backlog = "未排程"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("视图", selection: $selectedTab) {
                    ForEach(TaskTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Category filter
                CategoryFilterBar(selectedCategory: $viewModel.selectedCategory)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Divider()

                // Content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedTab {
                        case .today:
                            TodayView(viewModel: viewModel)
                        case .week:
                            WeekView(viewModel: viewModel)
                        case .backlog:
                            BacklogView(viewModel: viewModel)
                        }
                    }
                    .padding()
                }

                Divider()

                // Bottom toolbar
                HStack {
                    Button(action: { showingAddTask = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("新增任务")
                        }
                    }

                    Spacer()

                    if selectedTab == .week || selectedTab == .backlog {
                        Button(action: { viewModel.runAutoplan() }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("自动排程")
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding()
                .background(Color.appBackground)
            }
            .navigationTitle("任务中枢")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSortOptions = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSortOptions) {
                SortOptionsView(sortOption: $viewModel.sortOption)
            }
        }
    }
}

// MARK: - Sort Options View

@available(iOS 17.0, *)
struct SortOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortOption: TaskSortOption

    var body: some View {
        NavigationView {
            List {
                Section("排序方式") {
                    ForEach(TaskSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("排序選項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category Filter Bar

@available(iOS 17.0, *)
struct CategoryFilterBar: View {
    @Binding var selectedCategory: TaskCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "全部",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(TaskCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        color: Color.forCategory(category),
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct CategoryChip: View {
    let title: String
    var color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.black : Color.appSecondaryBackground)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Today View

@available(iOS 17.0, *)
struct TodayView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.todayTasks)

        if tasks.isEmpty {
            EmptyStateView(message: "今天没有任务 ✨")
        } else {
            ForEach(tasks) { task in
                TaskRow(task: task) {
                    viewModel.toggleTaskDone(task: task)
                }
            }
        }
    }
}

// MARK: - Week View

@available(iOS 17.0, *)
struct WeekView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let stats = viewModel.weeklyStatistics()
        let tasks = viewModel.filteredTasks(viewModel.weekTasks)

        VStack(spacing: 16) {
            // Weekly stats
            ForEach(stats, id: \.day) { stat in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(stat.day.formatLong())
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("预估 \(stat.duration / 60) 小时")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    let dayTasks = tasks.filter { task in
                        guard let planned = task.plannedDate else { return false }
                        return Calendar.current.isDate(planned, equalTo: stat.day, toGranularity: .day)
                    }

                    if dayTasks.isEmpty {
                        Text("无任务")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(dayTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Backlog View

@available(iOS 17.0, *)
struct BacklogView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.backlogTasks)

        if tasks.isEmpty {
            EmptyStateView(message: "没有未排程的任务 🎉")
        } else {
            ForEach(tasks) { task in
                TaskRow(task: task) {
                    viewModel.toggleTaskDone(task: task)
                }
            }
        }
    }
}

// MARK: - Empty State

@available(iOS 17.0, *)
struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.vertical, 40)
        }
    }
}

// MARK: - Add Task View (placeholder)

@available(iOS 17.0, *)
struct AddTaskView: View {
    @ObservedObject var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .personal
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date()

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("任务标题", text: $title)
                    TextField("描述（选填）", text: $description)
                    Picker("分类", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section("时间估计") {
                    HStack {
                        Text("预估时长")
                        Spacer()
                        Text("\(String(format: "%.1f", estimatedHours)) 小时")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                }

                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("截止时间", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("新增任务")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        viewModel.createTask(
                            title: title,
                            category: category,
                            deadline: hasDeadline ? deadline : nil,
                            estimatedMinutes: Int(estimatedHours * 60)
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
