import SwiftUI

struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? .green : .gray)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(task.title)
                    .font(.system(size: 15, weight: .medium))
                    .strikethrough(task.isDone)
                    .foregroundColor(task.isDone ? .gray : .primary)

                // Description
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Meta info
                HStack(spacing: 8) {
                    // Category tag
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.forCategory(task.category))
                            .frame(width: 6, height: 6)
                        Text(task.category.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Estimated time
                    if let hours = task.estimatedHours {
                        Text("约 \(String(format: "%.1f", hours)) 小时")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Deadline
                    if let deadline = task.deadlineAt {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(deadline.formatShort())
                                .font(.system(size: 11))
                        }
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            TaskRow(
                task: Task(
                    userId: "test",
                    title: "完成数据库作业",
                    description: "第五章习题 1-10",
                    category: .school,
                    deadlineAt: Date().addingTimeInterval(86400),
                    estimatedMinutes: 120
                ),
                onToggle: {}
            )

            TaskRow(
                task: Task(
                    userId: "test",
                    title: "晚班工作",
                    category: .work,
                    priority: .high,
                    estimatedMinutes: 240,
                    isDone: true
                ),
                onToggle: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
