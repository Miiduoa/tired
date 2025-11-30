import SwiftUI

@available(iOS 17.0, *)
struct TaskRow: View {
    let task: Task
    let isBlocked: Bool
    let onToggle: () async -> Bool
    var onTap: (() -> Void)? = nil
    var showSubtasks: Bool = true
    @State private var isProcessing = false
    @State private var grade: Grade? = nil // 作業成績（新增）

    private let gradeService = GradeService() // 成績服務

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: AppDesignSystem.paddingMedium) {
                // Left side: Priority indicator + Checkbox
                VStack(spacing: 4) {
                    // Priority indicator
                    priorityIndicator
                        .accessibilityLabel("優先級: \(task.priority.displayName)")

                    // Checkbox
                    Button {
                        _Concurrency.Task {
                            guard !isProcessing else { return }
                            await MainActor.run { isProcessing = true }
                            let success = await onToggle()
                            if !success {
                                // Toast is already shown by ViewModel in most cases
                            }
                            try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
                            await MainActor.run { isProcessing = false }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(checkboxColor, lineWidth: 2)
                                .frame(width: 24, height: 24)

                            if task.isDone {
                                Circle()
                                    .fill(AppDesignSystem.accentColor)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlocked || isProcessing)
                    .accessibilityLabel(task.isDone ? "標記為未完成" : "標記為完成")
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row with status badge
                    HStack(alignment: .top) {
                        if isBlocked && !task.isDone {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("等待依賴")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                            .accessibilityLabel("任務已鎖定，等待依賴任務完成")
                        }
                        
                        Text(task.title)
                            .font(AppDesignSystem.bodyFont.weight(.semibold))
                            .strikethrough(task.isDone)
                            .foregroundColor(task.isDone ? .secondary : (isBlocked ? .secondary.opacity(0.7) : .primary))
                            .lineLimit(2)

                        Spacer()

                        // Status badge
                        if !task.isDone {
                            statusBadge
                        }
                    }

                    // Description
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Tags
                    if let tags = task.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags.prefix(3), id: \.self) { tag in
                                    TagView(text: tag)
                                }
                                if tags.count > 3 {
                                    Text("+\(tags.count - 3)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("標籤: \(tags.joined(separator: ", "))")
                    }

                    // Subtask progress
                    if showSubtasks && task.totalSubtaskCount > 0 {
                        subtaskProgressView
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("子任務進度: \(task.completedSubtaskCount) of \(task.totalSubtaskCount) 完成")
                    }

                    // Meta info row
                    metaInfoRow
                }
            }
            .padding(AppDesignSystem.paddingMedium)

            // Progress bar at bottom (if has subtasks)
            if task.totalSubtaskCount > 0 {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(AppDesignSystem.accentColor.opacity(0.3))
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(AppDesignSystem.accentColor)
                                .frame(width: geometry.size.width * task.subtaskProgress, height: 3)
                        }
                }
                .frame(height: 3)
                .accessibilityLabel("子任務進度 \(Int(task.subtaskProgress * 100))%")
            }
        }
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
        .opacity(isBlocked ? 0.7 : 1.0)
        .overlay(
            // Left edge color indicator based on category
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.forCategory(task.category))
                    .frame(width: 4)
                Spacer()
            }
            .padding(.vertical, 8)
            .accessibilityHidden(true)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isBlocked {
                onTap?()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(isBlocked ? "此任務被其他任務鎖定，無法操作" : "點擊以查看詳情")
        .task {
            // 載入作業成績（Moodle-like 功能）
            if task.taskType == .homework, let taskId = task.id {
                do {
                    grade = try await gradeService.getTaskGrade(taskId: taskId)
                } catch {
                    print("❌ Error loading grade for task \(taskId): \(error)")
                }
            }
        }
    }

    // MARK: - Accessibility
    
    private var accessibilitySummary: String {
        var summary = ""
        
        summary += task.title
        summary += ", "
        
        if task.isDone {
            summary += "已完成"
        } else {
            summary += "未完成"
            
            if isBlocked {
                summary += ", 已鎖定"
            }
            
            if task.isOverdue {
                summary += ", 已過期"
            } else if task.isDueSoon {
                summary += ", 即將到期"
            }
            
            if let deadline = task.deadlineAt {
                summary += ", 截止於 \(formatDeadline(deadline))"
            }
        }
        
        summary += ", 優先級: \(task.priority.displayName)"
        summary += ", 分類: \(task.category.displayName)"
        
        if let tags = task.tags, !tags.isEmpty {
            summary += ", 標籤: \(tags.joined(separator: ", "))"
        }
        
        if task.totalSubtaskCount > 0 {
            summary += ", \(task.completedSubtaskCount) of \(task.totalSubtaskCount) 個子任務已完成"
        }
        
        return summary
    }


    // MARK: - Subviews

    private var priorityIndicator: some View {
        Group {
            switch task.priority {
            case .high:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            case .medium:
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            case .low:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
        }
    }

    private var checkboxColor: Color {
        if task.isDone {
            return AppDesignSystem.accentColor
        }
        if isBlocked {
            return .secondary.opacity(0.5)
        }
        if task.isOverdue {
            return .red
        }
        if task.isDueSoon {
            return .orange
        }
        return .secondary
    }

    private var statusBadge: some View {
        Group {
            // 作業成績顯示（Moodle-like 功能）
            if task.taskType == .homework {
                if let grade = grade, grade.isReleased {
                    GradeBadge(grade: grade)
                } else if task.isDone {
                    StatusBadge(text: "待評分", color: .blue)
                } else if task.isOverdue {
                    StatusBadge(text: "已過期", color: .red)
                } else if task.isDueSoon {
                    StatusBadge(text: "即將到期", color: .orange)
                }
            } else {
                // 非作業任務的原有邏輯
                if task.isOverdue {
                    StatusBadge(text: "已過期", color: .red)
                } else if task.isDueSoon {
                    StatusBadge(text: "即將到期", color: .orange)
                } else if task.priority == .high {
                    StatusBadge(text: "高優先", color: .red.opacity(0.8))
                }
            }
        }
    }

    private var subtaskProgressView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppDesignSystem.accentColor)
                        .frame(width: geometry.size.width * task.subtaskProgress, height: 4)
                }
            }
            .frame(width: 50, height: 4)
        }
    }

    private var metaInfoRow: some View {
        HStack(spacing: AppDesignSystem.paddingSmall) {
            // Category tag
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.forCategory(task.category))
                    .frame(width: 6, height: 6)
                Text(task.category.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.forCategory(task.category).opacity(0.1))
            .cornerRadius(4)

            // Estimated time
            if let hours = task.estimatedHours {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formatDuration(hours))
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }

            // Focus sessions count
            if let sessions = task.focusSessions, !sessions.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(sessions.count)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
            }
            
            // Reminder indicator
            if task.hasReminder {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .accessibilityLabel("已設定提醒")
            }
            
            // Dependency indicator
            if task.hasDependency {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .accessibilityLabel("有前置依賴任務")
            }

            Spacer()

            // Deadline
            if let deadline = task.deadlineAt {
                HStack(spacing: 3) {
                    Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                        .font(.system(size: 10))
                    Text(formatDeadline(deadline))
                        .font(.system(size: 11, weight: task.isOverdue || task.isDueSoon ? .semibold : .regular))
                }
                .foregroundColor(deadlineColor)
            }

            // Recurrence indicator
            if task.recurrence != nil {
                Image(systemName: "repeat")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .accessibilityLabel("重複任務")
            }
        }
    }

    private var deadlineColor: Color {
        if task.isOverdue { return .red }
        if task.isDueSoon { return .orange }
        return .secondary
    }

    private func formatDuration(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))分"
        } else if hours == floor(hours) {
            return "\(Int(hours))小時"
        } else {
            return String(format: "%.1f小時", hours)
        }
    }

    private func formatDeadline(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天 \(date.formatTime())"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else if let days = task.daysUntilDeadline {
            if days < 0 {
                return "逾期 \(abs(days)) 天"
            } else if days <= 7 {
                return "\(days) 天後"
            }
        }
        return date.formatShort()
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

@available(iOS 17.0, *)
struct TagView: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppDesignSystem.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppDesignSystem.accentColor.opacity(0.1))
            .cornerRadius(4)
    }
}

@available(iOS 17.0, *)
struct GradeBadge: View {
    let grade: Grade

    var body: some View {
        HStack(spacing: 4) {
            // 成績圖標
            Image(systemName: grade.isGraded ? "checkmark.seal.fill" : "clock.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)

            // 成績文字
            Text(grade.displayGrade)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(gradeBackgroundColor)
        .cornerRadius(6)
    }

    private var gradeBackgroundColor: Color {
        // 解析 hex 顏色字符串
        let hexColor = grade.gradeColor
        let hex = hexColor.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255.0
        let g = Double((int & 0x00FF00) >> 8) / 255.0
        let b = Double(int & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Compact Task Row (for lists with many items)

@available(iOS 17.0, *)
struct CompactTaskRow: View {
    let task: Task
    let isBlocked: Bool
    let onToggle: () async -> Bool
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            // Priority + Checkbox
            HStack(spacing: 6) {
                // Priority dot
                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("優先級: \(task.priority.displayName)")

                // Checkbox
                Button {
                    _Concurrency.Task {
                        guard !isProcessing else { return }
                        await MainActor.run { isProcessing = true }
                        let success = await onToggle()
                        if !success {
                            ToastManager.shared.showToast(message: "同步任務狀態失敗，請稍後再試。", type: .error)
                        }
                        try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
                        await MainActor.run { isProcessing = false }
                    }
                } label: {
                    ZStack {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(task.isDone ? AppDesignSystem.accentColor : .secondary)
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isBlocked)
                .accessibilityLabel(task.isDone ? "標記為未完成" : "標記為完成")
            }

            // Title
            if isBlocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("任務已鎖定")
            }
            Text(task.title)
                .font(.system(size: 15, weight: .medium))
                .strikethrough(task.isDone)
                .foregroundColor(task.isDone ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            // Quick info
            HStack(spacing: 8) {
                // Category
                Circle()
                    .fill(Color.forCategory(task.category))
                    .frame(width: 8, height: 8)

                // Deadline indicator
                if task.isOverdue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else if task.isDueSoon {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                } else if let deadline = task.deadlineAt {
                    Text(deadline.formatShort())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityHidden(true) // Meta info is included in the main summary
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.appSecondaryBackground.opacity(0.5))
        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
        .opacity(isBlocked ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(isBlocked ? "此任務被其他任務鎖定，無法操作" : "點擊以查看詳情")
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private var accessibilitySummary: String {
        var summary = ""
        summary += task.title
        summary += ", "
        
        if task.isDone {
            summary += "已完成"
        } else {
            summary += "未完成"
            if isBlocked {
                summary += ", 已鎖定"
            }
            if task.isOverdue {
                summary += ", 已過期"
            }
        }
        summary += ", 優先級: \(task.priority.displayName)"
        return summary
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: AppDesignSystem.paddingMedium) {
                    // High priority with subtasks
                    TaskRow(
                        task: Task(
                            userId: "test",
                            title: "完成資料庫作業",
                            description: "第五章習題 1-10，記得查閱文獻並整理筆記。",
                            category: .school,
                            priority: .high,
                            tags: ["作業", "期末", "重要"],
                            deadlineAt: Date().addingTimeInterval(3600 * 6),
                            estimatedMinutes: 120,
                            subtasks: [
                                Subtask(title: "看課本第五章", isDone: true),
                                Subtask(title: "完成習題1-5"),
                                Subtask(title: "完成習題6-10"),
                                Subtask(title: "整理筆記")
                            ],
                            dependsOnTaskIds: ["some-other-task"]
                        ),
                        isBlocked: true,
                        onToggle: { await MainActor.run { true } }
                    )

                    // Completed task
                    TaskRow(
                        task: Task(
                            userId: "test",
                            title: "處理客戶報告",
                            category: .work,
                            priority: .medium,
                            estimatedMinutes: 240,
                            plannedDate: Date().addingTimeInterval(-86400),
                            isDone: true
                        ),
                        isBlocked: false,
                        onToggle: { await MainActor.run { true } }
                    )

                    // Overdue task
                    TaskRow(
                        task: Task(
                            userId: "test",
                            title: "參加社團幹部會議",
                            description: "討論下學期活動規劃",
                            category: .club,
                            priority: .medium,
                            deadlineAt: Date().addingTimeInterval(-86400),
                            estimatedMinutes: 60
                        ),
                        isBlocked: false,
                        onToggle: { await MainActor.run { true } }
                    )

                    // Low priority personal task
                    TaskRow(
                        task: Task(
                            userId: "test",
                            title: "整理房間",
                            category: .personal,
                            priority: .low,
                            estimatedMinutes: 30,
                            recurrence: TaskRecurrence(type: .weekly, interval: 1)
                        ),
                        isBlocked: false,
                        onToggle: { await MainActor.run { true } }
                    )

                    Divider().padding(.vertical)

                    Text("緊湊模式")
                        .font(.headline)

                    CompactTaskRow(
                        task: Task(
                            userId: "test",
                            title: "回覆郵件",
                            category: .work,
                            priority: .medium,
                            deadlineAt: Date().addingTimeInterval(3600 * 2)
                        ),
                        isBlocked: true,
                        onToggle: { await MainActor.run { true } }
                    )
                }
                .padding(AppDesignSystem.paddingMedium)
            }
        }
    }
}
