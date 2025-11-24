import SwiftUI

@available(iOS 17.0, *)
struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var selectedTab: TaskTab = .today
    @State private var showingAddTask = false
    @State private var showingSortOptions = false
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var showQuickAdd = false
    @State private var quickAddTitle = ""

    enum TaskTab: String, CaseIterable {
        case today = "今天"
        case week = "本週"
        case backlog = "待辦"

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .week: return "calendar"
            case .backlog: return "tray.full.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

            NavigationView {
                VStack(spacing: 0) {
                    // Stats header
                    statsHeader

                    // Search bar (if active)
                    if showingSearch {
                        searchBar
                    }

                    // Tab selector with icons
                    customTabSelector

                    // Category filter
                    CategoryFilterBar(selectedCategory: $viewModel.selectedCategory)
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                        .padding(.bottom, AppDesignSystem.paddingSmall)

                    // Content
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        contentView
                    }

                    // Bottom toolbar
                    bottomToolbar
                }
                .navigationTitle("任務中樞")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showingSearch.toggle()
                                if !showingSearch {
                                    searchText = ""
                                }
                            }
                        } label: {
                            Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(showingSearch ? .red : .primary)
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingSortOptions = true
                            } label: {
                                Label("排序方式", systemImage: "arrow.up.arrow.down")
                            }

                            Divider()

                            ForEach(TaskSortOption.allCases, id: \.self) { option in
                                Button {
                                    viewModel.sortOption = option
                                } label: {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.rawValue)
                                        if viewModel.sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.primary)
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

            // Quick add overlay
            if showQuickAdd {
                quickAddOverlay
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatMiniCard(
                    title: "今日",
                    value: "\(viewModel.todayTasks.count)",
                    icon: "sun.max.fill",
                    color: .orange,
                    isSelected: selectedTab == .today
                )
                .onTapGesture { selectedTab = .today }

                StatMiniCard(
                    title: "本週",
                    value: "\(viewModel.weekTasks.count)",
                    icon: "calendar",
                    color: .blue,
                    isSelected: selectedTab == .week
                )
                .onTapGesture { selectedTab = .week }

                StatMiniCard(
                    title: "待辦",
                    value: "\(viewModel.backlogTasks.count)",
                    icon: "tray.full.fill",
                    color: .purple,
                    isSelected: selectedTab == .backlog
                )
                .onTapGesture { selectedTab = .backlog }

                // Overdue indicator
                let overdueCount = viewModel.todayTasks.filter { $0.isOverdue }.count +
                                   viewModel.weekTasks.filter { $0.isOverdue }.count
                if overdueCount > 0 {
                    StatMiniCard(
                        title: "逾期",
                        value: "\(overdueCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        isSelected: false
                    )
                }
            }
            .padding(.horizontal, AppDesignSystem.paddingMedium)
            .padding(.vertical, AppDesignSystem.paddingSmall)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜尋任務...", text: $searchText)
                .textFieldStyle(.plain)
                .font(AppDesignSystem.bodyFont)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
        .padding(.horizontal, AppDesignSystem.paddingMedium)
        .padding(.bottom, AppDesignSystem.paddingSmall)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Custom Tab Selector

    private var customTabSelector: some View {
        HStack(spacing: 4) {
            ForEach(TaskTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ?
                        AnyView(AppDesignSystem.accentColor) :
                        AnyView(Color.clear)
                    )
                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                }
            }
        }
        .padding(4)
        .background(Material.thin)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium + 4)
        .padding(.horizontal, AppDesignSystem.paddingMedium)
        .padding(.bottom, AppDesignSystem.paddingSmall)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入中...")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: AppDesignSystem.paddingMedium) {
                // Search results
                if showingSearch && !searchText.isEmpty {
                    searchResultsView
                } else {
                    switch selectedTab {
                    case .today:
                        TodayTasksView(viewModel: viewModel)
                    case .week:
                        WeekTasksView(viewModel: viewModel)
                    case .backlog:
                        BacklogTasksView(viewModel: viewModel)
                    }
                }
            }
            .padding(AppDesignSystem.paddingMedium)
        }
        .refreshable {
            viewModel.setupSubscriptions()
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        let filteredTasks = allTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText) ||
            (task.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (task.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
        }

        return Group {
            if filteredTasks.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "找不到結果",
                    message: "嘗試不同的搜尋關鍵字"
                )
            } else {
                ForEach(filteredTasks) { task in
                    TaskRow(task: task) {
                        viewModel.toggleTaskDone(task: task)
                    }
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // Quick add button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showQuickAdd = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppDesignSystem.accentColor)
                    .shadow(color: AppDesignSystem.accentColor.opacity(0.3), radius: 8, y: 4)
            }

            Spacer()

            // Add task button
            Button {
                showingAddTask = true
            } label: {
                Label("新增任務", systemImage: "square.and.pencil")
                    .font(AppDesignSystem.bodyFont.weight(.semibold))
            }
            .buttonStyle(GlassmorphicButtonStyle(textColor: .primary, cornerRadius: AppDesignSystem.cornerRadiusMedium))

            // Auto plan button (only for week/backlog)
            if selectedTab == .week || selectedTab == .backlog {
                Button {
                    viewModel.runAutoplan()
                } label: {
                    Label("排程", systemImage: "wand.and.stars")
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                }
                .buttonStyle(GlassmorphicButtonStyle(textColor: AppDesignSystem.accentColor, cornerRadius: AppDesignSystem.cornerRadiusMedium))
                .disabled(viewModel.isLoading)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Material.bar)
    }

    // MARK: - Quick Add Overlay

    private var quickAddOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showQuickAdd = false
                        quickAddTitle = ""
                    }
                }

            VStack(spacing: 16) {
                Text("快速新增")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    TextField("輸入任務名稱...", text: $quickAddTitle)
                        .textFieldStyle(FrostedTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            quickAddTask()
                        }

                    Button {
                        quickAddTask()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(quickAddTitle.isEmpty ? .secondary : AppDesignSystem.accentColor)
                    }
                    .disabled(quickAddTitle.isEmpty)
                }

                // Quick category selection
                HStack(spacing: 8) {
                    ForEach(TaskCategory.allCases, id: \.self) { category in
                        Button {
                            quickAddTask(category: category)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.forCategory(category))
                                    .frame(width: 32, height: 32)
                                Text(category.displayName)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(quickAddTitle.isEmpty)
                    }
                }
            }
            .padding(AppDesignSystem.paddingLarge)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusLarge)
            .padding(AppDesignSystem.paddingLarge)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func quickAddTask(category: TaskCategory = .personal) {
        guard !quickAddTitle.isEmpty else { return }

        viewModel.createTask(
            title: quickAddTitle,
            description: nil,
            category: category,
            priority: .medium,
            deadline: nil,
            estimatedMinutes: 60,
            plannedDate: selectedTab == .today ? Date() : nil,
            isDateLocked: false,
            sourceOrgId: nil
        )

        withAnimation(.spring(response: 0.3)) {
            showQuickAdd = false
            quickAddTitle = ""
        }
    }
}

// MARK: - Stat Mini Card

@available(iOS 17.0, *)
struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? color.opacity(0.15) : Material.thin)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Today Tasks View

@available(iOS 17.0, *)
struct TodayTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.todayTasks)
        let overdueTasks = tasks.filter { $0.isOverdue }
        let dueSoonTasks = tasks.filter { $0.isDueSoon && !$0.isOverdue }
        let normalTasks = tasks.filter { !$0.isOverdue && !$0.isDueSoon }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "sun.max.fill",
                title: "今天沒有任務",
                message: "享受美好的一天吧！"
            )
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // Overdue section
                if !overdueTasks.isEmpty {
                    TaskSection(title: "已過期", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(overdueTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Due soon section
                if !dueSoonTasks.isEmpty {
                    TaskSection(title: "即將到期", icon: "clock.fill", color: .orange) {
                        ForEach(dueSoonTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Normal tasks
                if !normalTasks.isEmpty {
                    TaskSection(title: "今日任務", icon: "checklist", color: .primary) {
                        ForEach(normalTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Week Tasks View

@available(iOS 17.0, *)
struct WeekTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let stats = viewModel.weeklyStatistics()
        let tasks = viewModel.filteredTasks(viewModel.weekTasks)

        VStack(spacing: AppDesignSystem.paddingMedium) {
            // Weekly capacity indicator
            WeeklyCapacityView(stats: stats, dailyCapacity: viewModel.userProfile?.dailyCapacityMinutes ?? 120)

            // Daily sections
            ForEach(stats, id: \.day) { stat in
                let dayTasks = tasks.filter { task in
                    guard let planned = task.plannedDate else { return false }
                    return Calendar.current.isDate(planned, equalTo: stat.day, toGranularity: .day)
                }

                DayTasksCard(
                    date: stat.day,
                    duration: stat.duration,
                    tasks: dayTasks,
                    onToggle: { task in
                        viewModel.toggleTaskDone(task: task)
                    }
                )
            }
        }
    }
}

// MARK: - Weekly Capacity View

@available(iOS 17.0, *)
struct WeeklyCapacityView: View {
    let stats: [(day: Date, duration: Int)]
    let dailyCapacity: Int

    private var totalMinutes: Int {
        stats.reduce(0) { $0 + $1.duration }
    }

    private var weeklyCapacity: Int {
        dailyCapacity * 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本週工作量")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(totalMinutes / 60) / \(weeklyCapacity / 60) 小時")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(totalMinutes > weeklyCapacity ? .red : .secondary)
            }

            // Progress bars for each day
            HStack(spacing: 4) {
                ForEach(stats.indices, id: \.self) { index in
                    let stat = stats[index]
                    let progress = min(1.0, Double(stat.duration) / Double(dailyCapacity))
                    let isOverloaded = stat.duration > dailyCapacity

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isOverloaded ? Color.red : AppDesignSystem.accentColor)
                            .frame(height: 40 * progress)
                            .frame(maxHeight: 40, alignment: .bottom)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 40)
                            )

                        Text(dayAbbreviation(stat.day))
                            .font(.system(size: 10))
                            .foregroundColor(Calendar.current.isDateInToday(stat.day) ? AppDesignSystem.accentColor : .secondary)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - Day Tasks Card

@available(iOS 17.0, *)
struct DayTasksCard: View {
    let date: Date
    let duration: Int
    let tasks: [Task]
    let onToggle: (Task) -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatLong())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isToday ? AppDesignSystem.accentColor : .primary)

                    if isToday {
                        Text("今天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppDesignSystem.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppDesignSystem.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tasks.count) 項任務")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("約 \(duration / 60) 小時")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Tasks
            if tasks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.secondary)
                    Text("沒有排程的任務")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, AppDesignSystem.paddingSmall)
            } else {
                ForEach(tasks) { task in
                    CompactTaskRow(task: task) {
                        onToggle(task)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
        .overlay(
            isToday ?
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(AppDesignSystem.accentColor, lineWidth: 2) :
            nil
        )
    }
}

// MARK: - Backlog Tasks View

@available(iOS 17.0, *)
struct BacklogTasksView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.backlogTasks)
        let highPriority = tasks.filter { $0.priority == .high }
        let mediumPriority = tasks.filter { $0.priority == .medium }
        let lowPriority = tasks.filter { $0.priority == .low }

        if tasks.isEmpty {
            EmptyStateView(
                icon: "tray.fill",
                title: "沒有待辦任務",
                message: "所有任務都已安排好了！"
            )
        } else {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // High priority
                if !highPriority.isEmpty {
                    TaskSection(title: "高優先", icon: "exclamationmark.triangle.fill", color: .red) {
                        ForEach(highPriority) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Medium priority
                if !mediumPriority.isEmpty {
                    TaskSection(title: "中優先", icon: "minus.circle.fill", color: .orange) {
                        ForEach(mediumPriority) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }

                // Low priority
                if !lowPriority.isEmpty {
                    TaskSection(title: "低優先", icon: "arrow.down.circle.fill", color: .blue) {
                        ForEach(lowPriority) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Task Section

@available(iOS 17.0, *)
struct TaskSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            .padding(.leading, 4)

            content
        }
    }
}

// MARK: - Empty State View

@available(iOS 17.0, *)
struct EmptyStateView: View {
    var icon: String = "checkmark.circle"
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(message)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesignSystem.paddingLarge * 2)
        .glassmorphicCard()
    }
}

// MARK: - Sort Options View

@available(iOS 17.0, *)
struct SortOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortOption: TaskSortOption

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                List {
                    ForEach(TaskSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(AppDesignSystem.accentColor)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .font(AppDesignSystem.bodyFont)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppDesignSystem.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("排序方式")
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
            HStack(spacing: AppDesignSystem.paddingSmall) {
                CategoryChip(
                    title: "全部",
                    color: .gray,
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
            .padding(.vertical, 8)
            .background(isSelected ? (color ?? AppDesignSystem.accentColor) : Material.thin)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Task View

@available(iOS 17.0, *)
struct AddTaskView: View {
    @ObservedObject var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .personal
    @State private var priority: TaskPriority = .medium
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var hasPlannedDate = false
    @State private var plannedDate = Date()
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // Basic info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("基本資訊")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("任務標題", text: $title)
                                .textFieldStyle(FrostedTextFieldStyle())

                            TextField("描述（選填）", text: $description, axis: .vertical)
                                .textFieldStyle(FrostedTextFieldStyle())
                                .lineLimit(3...6)

                            // Category picker
                            HStack {
                                Text("分類")
                                    .font(AppDesignSystem.bodyFont)
                                Spacer()
                                Menu {
                                    ForEach(TaskCategory.allCases, id: \.self) { cat in
                                        Button {
                                            category = cat
                                        } label: {
                                            HStack {
                                                Circle()
                                                    .fill(Color.forCategory(cat))
                                                    .frame(width: 12, height: 12)
                                                Text(cat.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.forCategory(category))
                                            .frame(width: 12, height: 12)
                                        Text(category.displayName)
                                            .font(AppDesignSystem.bodyFont)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Priority picker
                            HStack {
                                Text("優先級")
                                    .font(AppDesignSystem.bodyFont)
                                Spacer()
                                Picker("", selection: $priority) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Text(p.displayName).tag(p)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // Time section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("時間設定")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            // Estimated time
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("預估時長")
                                    Spacer()
                                    Text("\(formatHours(estimatedHours))")
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                                    .tint(AppDesignSystem.accentColor)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Deadline
                            VStack(spacing: 8) {
                                Toggle("設置截止日期", isOn: $hasDeadline)

                                if hasDeadline {
                                    DatePicker("", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Planned date
                            VStack(spacing: 8) {
                                Toggle("排程到特定日期", isOn: $hasPlannedDate)

                                if hasPlannedDate {
                                    DatePicker("", selection: $plannedDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("標籤")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            // Add tag
                            HStack {
                                TextField("新增標籤", text: $newTag)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addTag()
                                    }

                                Button {
                                    addTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(newTag.isEmpty ? .secondary : AppDesignSystem.accentColor)
                                }
                                .disabled(newTag.isEmpty)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Tags list
                            if !tags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                                .font(.system(size: 13, weight: .medium))
                                            Button {
                                                tags.removeAll { $0 == tag }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 12))
                                            }
                                        }
                                        .foregroundColor(AppDesignSystem.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppDesignSystem.accentColor.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()
                    }
                    .padding(AppDesignSystem.paddingMedium)
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(title.isEmpty ? .secondary : AppDesignSystem.accentColor)
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60)) 分鐘"
        } else if hours == floor(hours) {
            return "\(Int(hours)) 小時"
        } else {
            return String(format: "%.1f 小時", hours)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func createTask() {
        isCreating = true

        viewModel.createTask(
            title: title,
            description: description.isEmpty ? nil : description,
            category: category,
            priority: priority,
            deadline: hasDeadline ? deadline : nil,
            estimatedMinutes: Int(estimatedHours * 60),
            plannedDate: hasPlannedDate ? plannedDate : nil,
            isDateLocked: hasPlannedDate,
            sourceOrgId: nil
        )

        dismiss()
    }
}

// MARK: - Flow Layout

@available(iOS 17.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}
