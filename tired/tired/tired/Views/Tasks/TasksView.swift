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

            // Auto plan & Calendar section
            if selectedTab == .week || selectedTab == .backlog {
                if !viewModel.isCalendarAuthorized {
                    Button {
                        Task {
                            await viewModel.requestCalendarAccess()
                        }
                    } label: {
                        Label("連接行事曆", systemImage: "calendar.badge.plus")
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                    }
                    .buttonStyle(GlassmorphicButtonStyle(textColor: .primary, cornerRadius: AppDesignSystem.cornerRadiusMedium))
                }
                
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

