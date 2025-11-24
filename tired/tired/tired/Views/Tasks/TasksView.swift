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
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                VStack(spacing: 0) {
                    // Tab selector
                    Picker("視圖", selection: $selectedTab) {
                        ForEach(TaskTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(Material.thin) // Apply material directly to picker
                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                    .padding(AppDesignSystem.paddingMedium)

                    // Category filter
                    CategoryFilterBar(selectedCategory: $viewModel.selectedCategory)
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                        .padding(.bottom, AppDesignSystem.paddingSmall)

                    // Content
                    ScrollView {
                        LazyVStack(spacing: AppDesignSystem.paddingMedium) {
                            switch selectedTab {
                            case .today:
                                TodayView(viewModel: viewModel)
                            case .week:
                                WeekView(viewModel: viewModel)
                            case .backlog:
                                BacklogView(viewModel: viewModel)
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                    }

                    // Bottom toolbar
                    HStack(spacing: AppDesignSystem.paddingMedium) {
                        Button(action: { showingAddTask = true }) {
                            Label("新增任務", systemImage: "plus.circle.fill")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassmorphicButtonStyle(textColor: AppDesignSystem.accentColor, cornerRadius: AppDesignSystem.cornerRadiusMedium))

                        if selectedTab == .week || selectedTab == .backlog {
                            Button(action: { viewModel.runAutoplan() }) {
                                Label("自動排程", systemImage: "wand.and.stars")
                                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GlassmorphicButtonStyle(textColor: .primary, cornerRadius: AppDesignSystem.cornerRadiusMedium))
                            .disabled(viewModel.isLoading)
                        }
                    }
                    .padding(AppDesignSystem.paddingMedium)
                    .background(Material.bar) // Apply material to bottom bar
                }
                .navigationTitle("任務中樞")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingSortOptions = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.title2)
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
                .background(Color.clear) // Make NavigationView's background clear
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
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet
                Form {
                    Section("排序方式") {
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
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppDesignSystem.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear) // Make form row transparent
                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("排序選項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, textColor: .primary, cornerRadius: AppDesignSystem.cornerRadiusSmall))
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
                    color: .gray, // Custom color for "All"
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
            HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(AppDesignSystem.captionFont.weight(.medium))
            }
            .padding(.horizontal, AppDesignSystem.paddingSmall)
            .padding(.vertical, AppDesignSystem.paddingSmall / 2)
            .background(isSelected ? AppDesignSystem.accentColor : Material.thin) // Use accent color when selected
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(AppDesignSystem.cornerRadiusLarge) // More rounded for chips
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusLarge)
                    .stroke(AppDesignSystem.accentColor.opacity(isSelected ? 0.8 : 0.0), lineWidth: 1) // Accent border when selected
            )
        }
        .buttonStyle(.plain) // Remove default button styling
    }
}

// MARK: - Today View

@available(iOS 17.0, *)
struct TodayView: View {
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        let tasks = viewModel.filteredTasks(viewModel.todayTasks)

        if tasks.isEmpty {
            EmptyStateView(message: "今天没有任務 ✨")
                .glassmorphicCard() // Apply glassmorphic effect
                .padding(.vertical, AppDesignSystem.paddingLarge)
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

        VStack(spacing: AppDesignSystem.paddingMedium) {
            // Weekly stats
            ForEach(stats, id: \.day) { stat in
                VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                    HStack {
                        Text(stat.day.formatLong())
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("預估 \(stat.duration / 60) 小時")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }

                    let dayTasks = tasks.filter { task in
                        guard let planned = task.plannedDate else { return false }
                        return Calendar.current.isDate(planned, equalTo: stat.day, toGranularity: .day)
                    }

                    if dayTasks.isEmpty {
                        Text("無任務")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                            .padding(.vertical, AppDesignSystem.paddingSmall / 2)
                    } else {
                        ForEach(dayTasks) { task in
                            TaskRow(task: task) {
                                viewModel.toggleTaskDone(task: task)
                            }
                        }
                    }
                }
                .padding(AppDesignSystem.paddingMedium)
                .glassmorphicCard() // Apply glassmorphic effect to daily stats
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
            EmptyStateView(message: "沒有未排程的任務 🎉")
                .glassmorphicCard() // Apply glassmorphic effect
                .padding(.vertical, AppDesignSystem.paddingLarge)
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
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Text(message)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
        }
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
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Background for sheet
                Form {
                    Section {
                        TextField("任務標題", text: $title)
                            .textFieldStyle(FrostedTextFieldStyle())
                        TextField("描述（選填）", text: $description, axis: .vertical)
                            .textFieldStyle(FrostedTextFieldStyle())
                            .lineLimit(3...6)
                        Picker("分類", selection: $category) {
                            ForEach(TaskCategory.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("基本信息")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)

                    Section("時間估計") {
                        HStack {
                            Text("預估時長")
                                .font(AppDesignSystem.bodyFont)
                            Spacer()
                            Text("\(String(format: "%.1f", estimatedHours)) 小時")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                            .tint(AppDesignSystem.accentColor)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)

                    Section("截止日期") {
                        Toggle("設置截止日期", isOn: $hasDeadline)
                            .font(AppDesignSystem.bodyFont)
                        if hasDeadline {
                            DatePicker("截止時間", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                                .font(AppDesignSystem.bodyFont)
                        }
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)
                }
                .background(Color.clear) // Make Form background clear
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, textColor: .red, cornerRadius: AppDesignSystem.cornerRadiusSmall))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        createTask()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(textColor: .white, cornerRadius: AppDesignSystem.cornerRadiusSmall))
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }

    private func createTask() {
        isCreating = true

        Task {
            do {
                try await viewModel.createTask(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    category: category,
                    deadline: hasDeadline ? deadline : nil,
                    estimatedMinutes: Int(estimatedHours * 60)
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating task: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}