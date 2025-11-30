import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var selectedTab: TaskTab = .today
    @State private var viewMode: ViewMode = .list
    @State private var showingAddTask = false
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var showQuickAdd = false
    @State private var quickAddTitle = ""
    @State private var quickAddDeadline: Date? = nil
    @State private var quickAddPriority: TaskPriority = .medium
    @State private var showQuickAddDeadlinePicker = false
    @State private var showingAutoplan = false
    @Namespace private var tabAnimation
    @State private var processingTaskIds: Set<String> = []
    @State private var deepLinkTask: Task? = nil
    @State private var selectedCalendarDate: Date? = Date()

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
    
    enum ViewMode {
        case list
        case calendar
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()

            NavigationStack {
                ZStack(alignment: .bottom) {
                    if viewMode == .calendar {
                        calendarView
                    } else {
                        ScrollView {
                            VStack(spacing: AppDesignSystem.paddingMedium) {
                                heroHeader

                                statsHeader

                                searchAndActions

                                filterSection

                                contentView

                                Spacer(minLength: 32)
                            }
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                            .padding(.top, AppDesignSystem.paddingMedium)
                            .padding(.bottom, AppDesignSystem.paddingLarge)
                        }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            await MainActor.run {
                                viewModel.setupSubscriptions()
                            }
                        }
                    }

                    floatingActionBar
                }
                .navigationTitle("任務中樞")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAddTask) {
                    AddTaskView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingSortOptions) {
                    SortOptionsView(sortOption: $viewModel.sortOption)
                }
                .sheet(isPresented: $showingAutoplan) {
                    AutoPlanView(viewModel: viewModel)
                }
            }

            if showQuickAdd {
                quickAddOverlay
            }
            
            // Undo Snackbar
            if viewModel.showUndoOption {
                VStack {
                    Spacer()
                    HStack {
                        Text("任務已刪除")
                            .foregroundColor(.white)
                            .font(AppDesignSystem.bodyFont)
                        Spacer()
                        Button {
                            withAnimation {
                                viewModel.undoDelete()
                            }
                        } label: {
                            Text("復原")
                                .fontWeight(.bold)
                                .foregroundColor(AppDesignSystem.accentColor)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                    .shadow(radius: 10)
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Above tab bar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("處理中...")
                        .padding()
                        .background(Material.thin)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .zIndex(101)
            }
            
            // 慶祝動畫 Overlay
            if viewModel.showCelebration {
                CelebrationView(
                    achievement: viewModel.latestAchievement,
                    onDismiss: {
                        viewModel.dismissCelebration()
                    }
                )
                .zIndex(102)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.4), value: viewModel.showCelebration)
        .navigationDestination(item: $deepLinkTask) { task in
            TaskDetailView(viewModel: viewModel, task: task)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTaskDetail)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? String {
                // Fetch task and navigate
                _Concurrency.Task {
                    if let task = try? await viewModel.fetchTask(id: taskId) {
                        await MainActor.run {
                            self.deepLinkTask = task
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAutoplan)) { _ in
            showingAutoplan = true
        }
    }

    // MARK: - Header

    private var heroHeader: some View {
        let total = allTasks.count
        let completed = allTasks.filter { $0.isDone }.count
        
        return HStack(alignment: .center, spacing: AppDesignSystem.paddingMedium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今天的任務")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text(currentDateString)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if total > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppDesignSystem.accentColor)
                    Text("已完成 \(completed)/\(total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, AppDesignSystem.paddingSmall)
        .padding(.top, AppDesignSystem.paddingSmall)
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
            .padding(.horizontal, AppDesignSystem.paddingSmall)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Search & Actions

    private var searchAndActions: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜尋任務、描述或標籤", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(AppDesignSystem.bodyFont)
                    .textInputAutocapitalization(.none)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("清除搜尋文字")
                }
            }
            .padding(AppDesignSystem.paddingMedium)
            .background(Color.appSecondaryBackground)
            .cornerRadius(AppDesignSystem.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )

            Button {
                showingSortOptions = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(AppDesignSystem.accentColor)
                    .padding(AppDesignSystem.paddingMedium)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                            .stroke(Color.appCardBorder, lineWidth: 1)
                    )
            }
            .accessibilityLabel("排序選項")
        }
    }
    
    // MARK: - Filters

    private var filterSection: some View {
        VStack(spacing: AppDesignSystem.paddingSmall) {
            // 分類篩選
            HStack {
                Text("分類：")
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
                
                CategoryFilterBar(selectedCategory: $viewModel.selectedCategory)
                
                Spacer()
            }
            
            // 組織篩選
            if !viewModel.userOrganizations.isEmpty {
                HStack {
                    Text("組織：")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button {
                            viewModel.selectedOrganizationId = nil
                        } label: {
                            HStack {
                                Text("所有組織")
                                if viewModel.selectedOrganizationId == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(viewModel.userOrganizations, id: \.id) { org in
                            Button {
                                viewModel.selectedOrganizationId = org.id
                            } label: {
                                HStack {
                                    Text(org.name)
                                    if org.id == viewModel.selectedOrganizationId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption)
                            Text(viewModel.selectedOrganizationId == nil 
                                 ? "所有組織" 
                                 : viewModel.userOrganizations.first(where: { $0.id == viewModel.selectedOrganizationId })?.name ?? "已選組織")
                                .font(AppDesignSystem.captionFont)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(viewModel.selectedOrganizationId == nil ? .secondary : AppDesignSystem.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appSecondaryBackground)
                        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                                .stroke(viewModel.selectedOrganizationId == nil ? Color.appCardBorder : AppDesignSystem.accentColor, lineWidth: 1)
                        )
                    }
                    
                    // 清除組織篩選按鈕
                    if viewModel.selectedOrganizationId != nil {
                        Button {
                            viewModel.selectedOrganizationId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppDesignSystem.paddingSmall)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Picker("視圖模式", selection: $viewMode) {
                Label("列表", systemImage: "list.bullet").tag(ViewMode.list)
                Label("日曆", systemImage: "calendar").tag(ViewMode.calendar)
            }
            .pickerStyle(.segmented)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                if !viewModel.isCalendarAuthorized {
                    Button {
                        _Concurrency.Task { await viewModel.requestCalendarAccess() }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
                
                Menu {
                    Button {
                        showingAutoplan = true
                    } label: {
                        Label("智能排程", systemImage: "wand.and.stars")
                    }
                    
                    Button {
                        viewModel.runAutoplan()
                    } label: {
                        Label("快速排程", systemImage: "bolt.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.setupSubscriptions()
                        }
                    } label: {
                        Label("重新整理", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }



    // MARK: - Content View

    private var contentView: some View {
        LazyVStack(spacing: AppDesignSystem.paddingMedium) {
            if let error = viewModel.errorMessage {
                InlineBanner(icon: "exclamationmark.triangle.fill", text: error, tint: .orange)
            }

            if !viewModel.timeConflicts.isEmpty {
                ConflictBanner(conflicts: viewModel.timeConflicts)
            }

            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if allTasks.isEmpty && trimmedQuery.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "現在沒有任務",
                    message: "建立一個新的任務或嘗試自動排程，保持節奏。"
                )
                .frame(maxWidth: .infinity)
            }

            if !trimmedQuery.isEmpty {
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
        .padding(.vertical, AppDesignSystem.paddingSmall)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
        let filteredTasks = allTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query) ||
            (task.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            (task.tags?.contains { $0.localizedCaseInsensitiveContains(query) } ?? false)
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
                    NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
                        TaskRow(task: task, isBlocked: viewModel.isTaskBlocked(task)) { await toggleTask(task) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleTask(_ task: Task) async -> Bool {
        guard let id = task.id else { return false }
        await MainActor.run {
            guard !processingTaskIds.contains(id) else { return }
            processingTaskIds.insert(id)
        }

        let success = await viewModel.toggleTaskDoneAsync(task: task)

        if success {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        try? await _Concurrency.Task.sleep(nanoseconds: 150_000_000)

        _ = await MainActor.run { processingTaskIds.remove(id) }

        return success
    }

    // MARK: - Floating Action Bar

    private var floatingActionBar: some View {
        HStack(spacing: 16) {
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showQuickAdd = true
                }
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundColor(AppDesignSystem.accentColor)
                    .padding(16)
                    .background(Color.appSecondaryBackground)
                    .clipShape(Circle())
                    .shadow(color: AppDesignSystem.shadow, radius: 4, x: 0, y: 2)
                    .overlay(
                        Circle().stroke(Color.appCardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("快速新增任務")

            Button {
                showingAddTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(16)
                    .background(AppDesignSystem.accentColor)
                    .clipShape(Circle())
                    .shadow(color: AppDesignSystem.shadow.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("新增任務")
        }
        .padding(.horizontal, AppDesignSystem.paddingLarge)
        .padding(.bottom, AppDesignSystem.paddingMedium)
    }

    // MARK: - Quick Add Overlay

    private var quickAddOverlay: some View {
        ZStack {
            quickAddBackground
            quickAddContent
        }
    }
    
    private var quickAddBackground: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showQuickAdd = false
                    quickAddTitle = ""
                }
            }
    }
    
    private var quickAddContent: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            quickAddDragIndicator
            quickAddHeaderText
            quickAddInputSection
            quickAddOptionsSection
            quickAddCategoryButtons
        }
        .standardCard(cornerRadius: AppDesignSystem.cornerRadiusLarge, padding: AppDesignSystem.paddingLarge)
        .padding(AppDesignSystem.paddingLarge)
        .transition(.scale.combined(with: .opacity))
        .sheet(isPresented: $showQuickAddDeadlinePicker) {
            QuickAddDeadlineSheet(
                deadline: $quickAddDeadline,
                isPresented: $showQuickAddDeadlinePicker
            )
            .presentationDetents([.medium])
        }
    }
    
    private var quickAddDragIndicator: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 40, height: 4)
    }
    
    private var quickAddHeaderText: some View {
        Text("快速新增")
            .font(AppDesignSystem.headlineFont)
            .foregroundColor(.primary)
    }
    
    private var quickAddInputSection: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            Image(systemName: "text.cursor")
                .foregroundColor(.secondary)
            TextField("輸入任務名稱...", text: $quickAddTitle)
                .textFieldStyle(.plain)
                .font(AppDesignSystem.bodyFont)
                .submitLabel(.done)
                .onSubmit { quickAddTask() }

            quickAddSubmitButton
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
    
    private var quickAddOptionsSection: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            // 優先級選擇
            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button {
                        quickAddPriority = priority
                    } label: {
                        HStack {
                            Image(systemName: priority == .high ? "exclamationmark.3" : priority == .medium ? "exclamationmark.2" : "exclamationmark")
                            Text(priority.displayName)
                            if quickAddPriority == priority {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(quickAddPriority == .high ? .red : quickAddPriority == .medium ? .orange : .blue)
                    Text(quickAddPriority.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appSecondaryBackground)
                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
            }
            
            // 截止日期選擇
            Button {
                showQuickAddDeadlinePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(quickAddDeadline != nil ? AppDesignSystem.accentColor : .secondary)
                    if let deadline = quickAddDeadline {
                        Text(deadline.formatShort())
                            .font(.system(size: 13, weight: .medium))
                    } else {
                        Text("截止日期")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appSecondaryBackground)
                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        .stroke(quickAddDeadline != nil ? AppDesignSystem.accentColor : Color.appCardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 清除截止日期
            if quickAddDeadline != nil {
                Button {
                    quickAddDeadline = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    private var quickAddSubmitButton: some View {
        Button {
            quickAddTask()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(quickAddTitle.isEmpty ? .secondary : AppDesignSystem.accentColor)
        }
        .disabled(quickAddTitle.isEmpty)
    }
    
    private var quickAddCategoryButtons: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            ForEach(TaskCategory.allCases, id: \.self) { category in
                quickAddCategoryButton(category: category)
            }
        }
    }
    
    private func quickAddCategoryButton(category: TaskCategory) -> some View {
        Button {
            quickAddTask(category: category)
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color.forCategory(category))
                    .frame(width: 36, height: 36)
                Text(category.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(quickAddTitle.isEmpty)
    }

    private func quickAddTask(category: TaskCategory = .personal) {
        guard !quickAddTitle.isEmpty else { return }
        
        let trimmedTitle = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            ToastManager.shared.showToast(message: "任務標題不能為空", type: .warning)
            return
        }

        _Concurrency.Task {
            let success = await viewModel.createTaskAsync(
                title: trimmedTitle,
                description: nil,
                category: category,
                priority: quickAddPriority,
                deadline: quickAddDeadline,
                estimatedMinutes: 60,
                plannedDate: selectedTab == .today ? Date() : nil,
                isDateLocked: false,
                sourceOrgId: nil,
                assigneeUserIds: nil,
                dependsOnTaskIds: [],
                tags: [],
                reminderAt: nil,
                reminderEnabled: false,
                subtasks: nil,
                completionPercentage: nil,
                taskType: .generic
            )
            
            await MainActor.run {
                if success {
                    // 優化：新增觸覺回饋
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    withAnimation(.spring(response: 0.3)) {
                        showQuickAdd = false
                        quickAddTitle = ""
                        quickAddDeadline = nil
                        quickAddPriority = .medium
                    }
                } else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    // 保留輸入以便重試
                    ToastManager.shared.showToast(message: "快速新增任務失敗，請稍後重試", type: .error)
                }
            }
        }
    }

    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(spacing: 0) {
            if calendarViewModel.isLoading {
                ProgressView("正在讀取日曆資料...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = calendarViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CalendarViewRepresentable(
                    interval: DateInterval(start: .distantPast, end: .distantFuture),
                    itemsByDate: calendarViewModel.calendarItems,
                    selectedDate: $selectedCalendarDate
                )
                .frame(height: 350)
                
                Divider()
                
                // 顯示選定日期的項目
                if let date = selectedCalendarDate,
                   let items = calendarViewModel.calendarItems[Calendar.current.startOfDay(for: date)],
                   !items.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: AppDesignSystem.paddingSmall) {
                            ForEach(items) { item in
                                CalendarItemRow(item: item)
                                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                                    .padding(.vertical, AppDesignSystem.paddingSmall)
                                    .background(Color.appSecondaryBackground)
                                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                                    .onTapGesture {
                                        handleCalendarItemTap(item)
                                    }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                    }
                } else {
                    VStack(spacing: AppDesignSystem.paddingSmall) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(selectedCalendarDate == nil ? "請選擇一個日期" : "這天沒有活動或任務")
                            .foregroundColor(.secondary)
                            .font(AppDesignSystem.bodyFont)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            calendarViewModel.fetchData()
        }
    }
    
    private func handleCalendarItemTap(_ item: CalendarItem) {
        switch item.type {
        case .task:
            _Concurrency.Task {
                if let task = try? await viewModel.fetchTask(id: item.id) {
                    await MainActor.run {
                        deepLinkTask = task
                    }
                }
            }
        case .event:
            // 處理事件點擊（可以導航到事件詳情）
            print("點擊了活動: \(item.title)")
        }
    }

    // MARK: - Metrics

    private var allTasks: [Task] {
        viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
    }

    private var completionRate: Double {
        let total = allTasks.count
        guard total > 0 else { return 0 }
        let completed = allTasks.filter { $0.isDone }.count
        return Double(completed) / Double(total)
    }

    private var overdueCount: Int {
        allTasks.filter { $0.isOverdue }.count
    }

    private var dueSoonCount: Int {
        allTasks.filter { $0.isDueSoon && !$0.isOverdue }.count
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }
}

private struct PillView: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct InlineBanner: View {
    let icon: String
    let text: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(text)
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, AppDesignSystem.paddingMedium)
        .background(Color.appSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
    }
}

private struct ConflictBanner: View {
    let conflicts: [TaskConflict]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .foregroundColor(.red)
                Text("發現行程衝突")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(conflicts.count) 個衝突")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }

            ForEach(conflicts.prefix(2)) { conflict in
                HStack(alignment: .top, spacing: 8) {
                    Text(conflict.severity.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflict.description)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(conflict.involvedOrganizations.isEmpty ? "個人行程" : "跨組織行程")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.appPrimaryBackground)
                .cornerRadius(8)
            }

            if conflicts.count > 2 {
                Text("還有 \(conflicts.count - 2) 個衝突...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Quick Add Deadline Sheet

@available(iOS 17.0, *)
private struct QuickAddDeadlineSheet: View {
    @Binding var deadline: Date?
    @Binding var isPresented: Bool
    @State private var selectedDate: Date = Date().addingTimeInterval(86400)
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppDesignSystem.paddingMedium) {
                // 快速選擇按鈕
                VStack(spacing: AppDesignSystem.paddingSmall) {
                    Text("快速選擇")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: AppDesignSystem.paddingSmall) {
                        QuickDateButton(title: "今天", date: Date()) { date in
                            selectedDate = date
                            deadline = date
                        }
                        QuickDateButton(title: "明天", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) { date in
                            selectedDate = date
                            deadline = date
                        }
                        QuickDateButton(title: "下週", date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()) { date in
                            selectedDate = date
                            deadline = date
                        }
                        QuickDateButton(title: "下個月", date: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()) { date in
                            selectedDate = date
                            deadline = date
                        }
                    }
                }
                .padding(.horizontal, AppDesignSystem.paddingMedium)
                
                Divider()
                
                // 日期選擇器
                DatePicker(
                    "截止日期",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, AppDesignSystem.paddingMedium)
                .onChange(of: selectedDate) {
                    deadline = selectedDate
                }
                
                Spacer()
            }
            .padding(.top, AppDesignSystem.paddingMedium)
            .navigationTitle("選擇截止日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") {
                        deadline = selectedDate
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let existingDeadline = deadline {
                selectedDate = existingDeadline
            }
        }
    }
}

@available(iOS 17.0, *)
private struct QuickDateButton: View {
    let title: String
    let date: Date
    let onSelect: (Date) -> Void
    
    var body: some View {
        Button {
            onSelect(date)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(date.formatShort())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.appSecondaryBackground)
            .cornerRadius(AppDesignSystem.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
