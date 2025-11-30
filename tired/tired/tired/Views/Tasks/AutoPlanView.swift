import SwiftUI

/// 智能排程設定與預覽視圖
@available(iOS 17.0, *)
struct AutoPlanView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TasksViewModel
    
    // 排程設定
    @State private var weeklyCapacity: Double = 10 // 小時
    @State private var dailyCapacity: Double = 2 // 小時
    @State private var useCustomDaily: Bool = false
    @State private var allowWeekends: Bool = false
    @State private var workdays: Set<Int> = [2, 3, 4, 5, 6] // 週一到週五
    
    // 預覽狀態
    @State private var isGeneratingPreview: Bool = false
    @State private var previewSchedule: [SchedulePreviewDay] = []
    @State private var suggestions: [SmartSuggestion] = []
    @State private var totalTasksToSchedule: Int = 0
    @State private var hasConflicts: Bool = false
    
    // 確認狀態
    @State private var showingConfirmation: Bool = false
    @State private var isApplying: Bool = false
    
    private let autoPlanService = AutoPlanService()
    private let analyticsService = TaskAnalyticsService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 智能建議區
                        if !suggestions.isEmpty {
                            suggestionsSection
                        }
                        
                        // 設定區
                        settingsSection
                        
                        // 預覽區
                        if !previewSchedule.isEmpty {
                            previewSection
                        }
                        
                        // 操作按鈕
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("智能排程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserPreferences()
                generateSuggestions()
            }
            .alert("確認排程", isPresented: $showingConfirmation) {
                Button("取消", role: .cancel) {}
                Button("確認套用") {
                    applySchedule()
                }
            } message: {
                Text("將會排程 \(totalTasksToSchedule) 個任務到未來兩週。此操作無法復原。")
            }
        }
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("智能建議")
                    .font(.headline)
            }
            
            ForEach(suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion) {
                    applySuggestion(suggestion)
                }
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("排程設定")
                .font(.headline)
            
            // 每週容量
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("每週工作容量")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(weeklyCapacity)) 小時")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $weeklyCapacity, in: 5...40, step: 1)
                    .tint(AppDesignSystem.accentColor)
                    .onChange(of: weeklyCapacity) { _, _ in
                        if !useCustomDaily {
                            dailyCapacity = weeklyCapacity / Double(workdays.count)
                        }
                    }
            }
            
            // 自訂每日容量
            Toggle("自訂每日容量", isOn: $useCustomDaily)
                .tint(AppDesignSystem.accentColor)
            
            if useCustomDaily {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日工作容量")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(dailyCapacity)) 小時")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $dailyCapacity, in: 1...8, step: 0.5)
                        .tint(AppDesignSystem.accentColor)
                }
            }
            
            Divider()
            
            // 工作日設定
            VStack(alignment: .leading, spacing: 8) {
                Text("工作日")
                    .font(.subheadline)
                
                HStack(spacing: 8) {
                    ForEach(weekdayOptions, id: \.0) { day in
                        WorkdayToggle(
                            label: day.1,
                            isSelected: workdays.contains(day.0),
                            action: {
                                toggleWorkday(day.0)
                            }
                        )
                    }
                }
            }
            
            Toggle("允許週末排程", isOn: $allowWeekends)
                .tint(AppDesignSystem.accentColor)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("排程預覽")
                    .font(.headline)
                Spacer()
                if hasConflicts {
                    Label("有衝突", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            ForEach(previewSchedule) { day in
                SchedulePreviewCard(day: day)
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                generatePreview()
            } label: {
                HStack {
                    if isGeneratingPreview {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "eye.fill")
                    }
                    Text("預覽排程")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appSecondaryBackground)
                .foregroundColor(.primary)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppDesignSystem.glassOverlay, lineWidth: 1)
                )
            }
            .disabled(isGeneratingPreview)
            
            Button {
                showingConfirmation = true
            } label: {
                HStack {
                    if isApplying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text("套用排程")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Group {
                        if previewSchedule.isEmpty {
                            Color.gray
                        } else {
                            AppDesignSystem.accentGradient
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(previewSchedule.isEmpty || isApplying)
        }
    }
    
    // MARK: - Weekday Options
    
    private var weekdayOptions: [(Int, String)] {
        [
            (1, "日"),
            (2, "一"),
            (3, "二"),
            (4, "三"),
            (5, "四"),
            (6, "五"),
            (7, "六")
        ]
    }
    
    // MARK: - Actions
    
    private func loadUserPreferences() {
        if let profile = viewModel.userProfile {
            weeklyCapacity = Double(profile.weeklyCapacityMinutes ?? 600) / 60.0
            if let daily = profile.dailyCapacityMinutes {
                dailyCapacity = Double(daily) / 60.0
                useCustomDaily = true
            }
        }
    }
    
    private func generateSuggestions() {
        _Concurrency.Task {
            guard let userId = viewModel.userId else { return }
            
            do {
                // 分析任務歷史
                let insights = try await analyticsService.generateProductivityInsights(userId: userId)
                let hourlyStats = try await analyticsService.getMostProductiveHours(userId: userId)
                let timeStats = try await analyticsService.getTimeEstimationAccuracy(userId: userId)
                
                var newSuggestions: [SmartSuggestion] = []
                
                // 基於生產力時間的建議
                if let bestHour = hourlyStats.first {
                    let hourStr = String(format: "%02d:00", bestHour.hour)
                    newSuggestions.append(SmartSuggestion(
                        id: UUID().uuidString,
                        icon: "clock.fill",
                        title: "最佳工作時段",
                        description: "您在 \(hourStr) 左右最有效率，建議將重要任務安排在這個時段。",
                        type: .info,
                        action: nil
                    ))
                }
                
                // 基於時間估計的建議
                if timeStats.averageEstimationError > 0.3 {
                    newSuggestions.append(SmartSuggestion(
                        id: UUID().uuidString,
                        icon: "timer",
                        title: "調整時間預估",
                        description: "您的時間估計平均誤差為 \(Int(timeStats.averageEstimationError * 100))%，建議增加緩衝時間。",
                        type: .warning,
                        action: .adjustEstimates
                    ))
                }
                
                // 基於待辦任務數量的建議
                let backlogCount = viewModel.backlogTasks.count
                if backlogCount > 10 {
                    newSuggestions.append(SmartSuggestion(
                        id: UUID().uuidString,
                        icon: "tray.full.fill",
                        title: "待辦任務過多",
                        description: "您有 \(backlogCount) 個未排程任務，建議先處理高優先級任務。",
                        type: .urgent,
                        action: .prioritizeBacklog
                    ))
                }
                
                // 基於過期任務的建議
                let overdueTasks = viewModel.todayTasks.filter { $0.isOverdue }
                if !overdueTasks.isEmpty {
                    newSuggestions.append(SmartSuggestion(
                        id: UUID().uuidString,
                        icon: "exclamationmark.triangle.fill",
                        title: "\(overdueTasks.count) 個過期任務",
                        description: "有任務已經過期，建議優先處理或重新安排截止日期。",
                        type: .urgent,
                        action: .rescheduleOverdue
                    ))
                }
                
                // 基於容量的建議
                let todayLoad = viewModel.todayTasks.reduce(0) { $0 + ($1.estimatedMinutes ?? 0) }
                let dailyCapacityMinutes = Int(dailyCapacity * 60)
                if todayLoad > dailyCapacityMinutes {
                    let overloadPercent = Int((Double(todayLoad) / Double(dailyCapacityMinutes) - 1) * 100)
                    newSuggestions.append(SmartSuggestion(
                        id: UUID().uuidString,
                        icon: "battery.100.bolt",
                        title: "今日超載 \(overloadPercent)%",
                        description: "今日任務量超過設定容量，建議分散到其他日期。",
                        type: .warning,
                        action: .redistributeToday
                    ))
                }
                
                await MainActor.run {
                    self.suggestions = newSuggestions
                }
            } catch {
                print("Error generating suggestions: \(error)")
            }
        }
    }
    
    private func toggleWorkday(_ day: Int) {
        if workdays.contains(day) {
            workdays.remove(day)
        } else {
            workdays.insert(day)
        }
        
        // 確保至少有一個工作日
        if workdays.isEmpty {
            workdays.insert(day)
        }
        
        // 更新每日容量
        if !useCustomDaily {
            dailyCapacity = weeklyCapacity / Double(workdays.count)
        }
    }
    
    private func generatePreview() {
        isGeneratingPreview = true
        
        _Concurrency.Task {
            let allTasks = viewModel.todayTasks + viewModel.weekTasks + viewModel.backlogTasks
            let unscheduledTasks = allTasks.filter { !$0.isDone && !$0.isDateLocked && $0.plannedDate == nil }
            
            let options = AutoPlanService.AutoPlanOptions(
                weeklyCapacityMinutes: Int(weeklyCapacity * 60),
                dailyCapacityMinutes: useCustomDaily ? Int(dailyCapacity * 60) : nil,
                workdayIndices: workdays,
                allowWeekends: allowWeekends
            )
            
            let (updatedTasks, count) = autoPlanService.autoplanWeek(tasks: allTasks, options: options)
            
            // 生成預覽數據
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var previewDays: [SchedulePreviewDay] = []
            
            for offset in 0..<14 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                
                let dayTasks = updatedTasks.filter { task in
                    guard let planned = task.plannedDate else { return false }
                    return calendar.isDate(planned, inSameDayAs: date)
                }
                
                if !dayTasks.isEmpty {
                    let totalMinutes = dayTasks.reduce(0) { $0 + ($1.estimatedMinutes ?? 0) }
                    let capacityMinutes = useCustomDaily ? Int(dailyCapacity * 60) : Int(weeklyCapacity * 60 / Double(workdays.count))
                    let isOverloaded = totalMinutes > capacityMinutes
                    
                    previewDays.append(SchedulePreviewDay(
                        id: UUID().uuidString,
                        date: date,
                        tasks: dayTasks.map { SchedulePreviewTask(id: $0.id ?? UUID().uuidString, title: $0.title, priority: $0.priority, minutes: $0.estimatedMinutes ?? 0) },
                        totalMinutes: totalMinutes,
                        capacityMinutes: capacityMinutes,
                        isOverloaded: isOverloaded
                    ))
                }
            }
            
            await MainActor.run {
                self.previewSchedule = previewDays
                self.totalTasksToSchedule = count
                self.hasConflicts = previewDays.contains { $0.isOverloaded }
                self.isGeneratingPreview = false
            }
        }
    }
    
    private func applySchedule() {
        isApplying = true
        
        viewModel.runAutoplan(
            weeklyCapacityOverride: Int(weeklyCapacity * 60),
            dailyCapacityOverride: useCustomDaily ? Int(dailyCapacity * 60) : nil
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isApplying = false
            dismiss()
        }
    }
    
    private func applySuggestion(_ suggestion: SmartSuggestion) {
        switch suggestion.action {
        case .adjustEstimates:
            // 增加 20% 緩衝時間
            weeklyCapacity *= 0.8
            dailyCapacity *= 0.8
        case .prioritizeBacklog:
            // 優先排程高優先級任務
            // 這會在預覽時自動處理
            generatePreview()
        case .rescheduleOverdue:
            // 跳轉到過期任務處理
            ToastManager.shared.showToast(message: "請在任務列表中處理過期任務", type: .info)
        case .redistributeToday:
            // 自動重新分配今日任務
            generatePreview()
        case .none:
            break
        }
    }
}

// MARK: - Supporting Types

struct SmartSuggestion: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let type: SuggestionType
    let action: SuggestionAction?
    
    enum SuggestionType {
        case info, warning, urgent
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .urgent: return .red
            }
        }
    }
    
    enum SuggestionAction {
        case adjustEstimates
        case prioritizeBacklog
        case rescheduleOverdue
        case redistributeToday
    }
}

struct SchedulePreviewDay: Identifiable {
    let id: String
    let date: Date
    let tasks: [SchedulePreviewTask]
    let totalMinutes: Int
    let capacityMinutes: Int
    let isOverloaded: Bool
    
    var loadPercentage: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(Double(totalMinutes) / Double(capacityMinutes), 1.5)
    }
}

struct SchedulePreviewTask: Identifiable {
    let id: String
    let title: String
    let priority: TaskPriority
    let minutes: Int
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct WorkdayToggle: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(isSelected ? AppDesignSystem.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
struct SuggestionCard: View {
    let suggestion: SmartSuggestion
    let onApply: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title2)
                .foregroundColor(suggestion.type.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if suggestion.action != nil {
                Button(action: onApply) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(suggestion.type.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(suggestion.type.color.opacity(0.1))
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
struct SchedulePreviewCard: View {
    let day: SchedulePreviewDay
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd (E)"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateFormatter.string(from: day.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(day.totalMinutes) / \(day.capacityMinutes) 分鐘")
                    .font(.caption)
                    .foregroundColor(day.isOverloaded ? .orange : .secondary)
            }
            
            // 容量進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.isOverloaded ? Color.orange : AppDesignSystem.accentColor)
                        .frame(width: geometry.size.width * min(day.loadPercentage, 1.0), height: 8)
                }
            }
            .frame(height: 8)
            
            // 任務列表
            ForEach(day.tasks) { task in
                HStack(spacing: 8) {
                    Circle()
                        .fill(task.priority.color)
                        .frame(width: 8, height: 8)
                    
                    Text(task.title)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(task.minutes)分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.appPrimaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - TaskPriority Color Extension

extension TaskPriority {
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

