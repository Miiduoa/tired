import SwiftUI

@available(iOS 17.0, *)
struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.paddingMedium) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? AppDesignSystem.accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain) // Ensure the button itself doesn't have default styling

            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                // Title
                Text(task.title)
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                    .strikethrough(task.isDone)
                    .foregroundColor(task.isDone ? .secondary : .primary)

                // Description
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Meta info
                HStack(spacing: AppDesignSystem.paddingSmall) {
                    // Category tag
                    HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                        Circle()
                            .fill(Color.forCategory(task.category))
                            .frame(width: 6, height: 6)
                        Text(task.category.displayName)
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }

                    // Estimated time
                    if let hours = task.estimatedHours {
                        Text("約 \(String(format: "%.1f", hours)) 小時")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Deadline
                    if let deadline = task.deadlineAt {
                        HStack(spacing: AppDesignSystem.paddingSmall / 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(deadline.formatShort())
                                .font(AppDesignSystem.captionFont)
                        }
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
            VStack(spacing: AppDesignSystem.paddingMedium) {
                TaskRow(
                    task: Task(
                        userId: "test",
                        title: "完成資料庫作業",
                        description: "第五章習題 1-10，記得查閱文獻。",
                        category: .school,
                        deadlineAt: Date().addingTimeInterval(86400 * 2), // Two days from now
                        estimatedMinutes: 120
                    ),
                    onToggle: {}
                )

                TaskRow(
                    task: Task(
                        userId: "test",
                        title: "處理客戶報告",
                        category: .work,
                        priority: .high,
                        estimatedMinutes: 240,
                        plannedDate: Date().addingTimeInterval(-86400), // Planned yesterday
                        isDone: true
                    ),
                    onToggle: {}
                )
                
                TaskRow(
                    task: Task(
                        userId: "test",
                        title: "參加社團活動",
                        category: .club,
                        deadlineAt: Date().addingTimeInterval(-86400), // Overdue
                        estimatedMinutes: 60
                    ),
                    onToggle: {}
                )
            }
            .padding(AppDesignSystem.paddingMedium)
        }
    }
}