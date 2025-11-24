import SwiftUI

@available(iOS 17.0, *)
struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void
    var onTap: (() -> Void)? = nil
    var showSubtasks: Bool = true

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content
                HStack(alignment: .top, spacing: AppDesignSystem.paddingMedium) {
                    // Left side: Priority indicator + Checkbox
                    VStack(spacing: 4) {
                        // Priority indicator
                        priorityIndicator

                        // Checkbox
                        Button(action: onToggle) {
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
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        // Title row with status badge
                        HStack(alignment: .top) {
                            Text(task.title)
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .strikethrough(task.isDone)
                                .foregroundColor(task.isDone ? .secondary : .primary)
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
                        }

                        // Subtask progress
                        if showSubtasks && task.totalSubtaskCount > 0 {
                            subtaskProgressView
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
                }
            }
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
            .overlay(
                // Left edge color indicator based on category
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.forCategory(task.category))
                        .frame(width: 4)
                    Spacer()
                }
                .padding(.vertical, 8)
            )
        }
        .buttonStyle(.plain)
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
            if task.isOverdue {
                StatusBadge(text: "已過期", color: .red)
            } else if task.isDueSoon {
                StatusBadge(text: "即將到期", color: .orange)
            } else if task.priority == .high {
                StatusBadge(text: "高優先", color: .red.opacity(0.8))
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

// MARK: - Compact Task Row (for lists with many items)

@available(iOS 17.0, *)
struct CompactTaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Priority + Checkbox
            HStack(spacing: 6) {
                // Priority dot
                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)

                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(task.isDone ? AppDesignSystem.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Title
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
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.appSecondaryBackground.opacity(0.5))
        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
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
                            ]
                        ),
                        onToggle: {}
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
                        onToggle: {}
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
                        onToggle: {}
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
                        onToggle: {}
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
                        onToggle: {}
                    )
                }
                .padding(AppDesignSystem.paddingMedium)
            }
        }
    }
}
