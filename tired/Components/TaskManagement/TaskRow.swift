import SwiftUI

// MARK: - Task Row Component
struct TaskRow: View {
    let task: Task
    var showDate: Bool
    var showCourse: Bool
    var onTap: (() -> Void)?
    var onComplete: (() -> Void)?
    var onFocusToggle: (() -> Void)?

    @State private var isCompleting = false

    var body: some View {
        HStack(spacing: 12) {
            // Complete Button
            Button(action: handleComplete) {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleting ? .green : .gray.opacity(0.5))
                    .animation(.spring(response: 0.3), value: isCompleting)
            }
            .buttonStyle(ScaleButtonStyle())

            // Task Content
            VStack(alignment: .leading, spacing: 6) {
                // Title & Priority
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    // Priority Badge
                    if task.priority == .P0 || task.priority == .P1 {
                        GlassBadge(
                            text: task.priority.rawValue,
                            color: task.priority == .P0 ? .red : .orange,
                            icon: "flag.fill"
                        )
                    }
                }

                // Metadata Row
                HStack(spacing: 8) {
                    // Deadline
                    if let deadline = task.deadlineAt {
                        DeadlineView(deadline: deadline, isOverdue: isOverdue)
                    }

                    // Course/Category
                    if showCourse {
                        if task.category == .school {
                            // TODO: Show course name
                            Text("課程")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else {
                            Text(categoryText)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Planned Date
                    if showDate, let planned = task.plannedWorkDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(DateUtils.relativeDateDescription(planned))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.blue)
                    }

                    // Effort
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(task.estimatedEffortMin)分")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)

                    // Blocked indicator
                    if task.blockedByTaskIds.count > 0 {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    // Focus star
                    if let onFocusToggle = onFocusToggle {
                        Button(action: onFocusToggle) {
                            Image(systemName: task.isTodayFocus ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundColor(task.isTodayFocus ? .yellow : .gray.opacity(0.5))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    // MARK: - Computed Properties

    private var isOverdue: Bool {
        guard let deadline = task.deadlineAt else { return false }
        return DateUtils.isBefore(deadline, Date())
    }

    private var borderColor: Color {
        if task.isTodayFocus {
            return Color.yellow.opacity(0.5)
        } else if isOverdue {
            return Color.red.opacity(0.3)
        } else {
            return Color.white.opacity(0.1)
        }
    }

    private var categoryText: String {
        switch task.category {
        case .work: return "工作"
        case .personal: return "個人"
        case .other: return "其他"
        default: return ""
        }
    }

    // MARK: - Actions

    private func handleComplete() {
        withAnimation(.spring(response: 0.3)) {
            isCompleting.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete?()
        }
    }
}

// MARK: - Deadline View
struct DeadlineView: View {
    let deadline: Date
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                .font(.system(size: 10))
            Text(DateUtils.relativeDateDescription(deadline))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(isOverdue ? .red : .orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((isOverdue ? Color.red : Color.orange).opacity(0.15))
        )
    }
}

// MARK: - Task Section
struct TaskSection: View {
    let title: String
    let icon: String
    let tasks: [Task]
    let emptyMessage: String
    var onTaskTap: ((Task) -> Void)?
    var onTaskComplete: ((Task) -> Void)?
    var onTaskFocusToggle: ((Task) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(tasks.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                    )
            }
            .padding(.horizontal, 4)

            // Tasks
            if tasks.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskRow(
                            task: task,
                            showDate: true,
                            showCourse: true,
                            onTap: { onTaskTap?(task) },
                            onComplete: { onTaskComplete?(task) },
                            onFocusToggle: { onTaskFocusToggle?(task) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct TaskRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    TaskRow(
                        task: Task(
                            userId: "user1",
                            title: "完成作業報告",
                            category: .school,
                            deadlineAt: Date().addingTimeInterval(3600 * 24),
                            priority: .P0,
                            isTodayFocus: true,
                            estimatedEffortMin: 120
                        ),
                        showDate: true,
                        showCourse: true,
                        onTap: { print("Tapped") },
                        onComplete: { print("Completed") },
                        onFocusToggle: { print("Focus toggled") }
                    )

                    TaskRow(
                        task: Task(
                            userId: "user1",
                            title: "準備期中考",
                            category: .school,
                            deadlineAt: Date().addingTimeInterval(-3600 * 24),
                            priority: .P1,
                            estimatedEffortMin: 60
                        ),
                        showDate: true,
                        showCourse: true
                    )
                }
                .padding()
            }
        }
    }
}
