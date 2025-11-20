import SwiftUI

@available(iOS 17.0, *)
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel

    let task: Task
    @State private var showingEditView = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 標題區域
                    VStack(alignment: .leading, spacing: 16) {
                        // 狀態指示器
                        HStack {
                            Button {
                                viewModel.toggleTaskDone(task: task)
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isDone ? .green : .gray)
                                    .font(.system(size: 32))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .strikethrough(task.isDone)
                                    .foregroundColor(task.isDone ? .secondary : .primary)

                                Text(task.isDone ? "已完成" : "待完成")
                                    .font(.system(size: 14))
                                    .foregroundColor(task.isDone ? .green : .orange)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.appSecondaryBackground)
                    }

                    Divider()

                    // 詳細信息
                    VStack(spacing: 0) {
                        // 分類
                        InfoRow(icon: "tag.fill", iconColor: Color(hex: task.category.color), title: "分類", value: task.category.displayName)

                        // 優先級
                        InfoRow(icon: "flag.fill", iconColor: priorityColor, title: "優先級", value: task.priority.displayName)

                        // 截止時間
                        if let deadline = task.deadlineAt {
                            InfoRow(
                                icon: "calendar",
                                iconColor: task.isOverdue ? .red : .blue,
                                title: "截止時間",
                                value: deadline.formatDateTime()
                            )

                            if task.isOverdue && !task.isDone {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("已逾期")
                                        .foregroundColor(.red)
                                }
                                .font(.system(size: 13))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }

                        // 預估時長
                        if let minutes = task.estimatedMinutes {
                            let hours = Double(minutes) / 60.0
                            InfoRow(
                                icon: "clock.fill",
                                iconColor: .purple,
                                title: "預估時長",
                                value: String(format: "%.1f 小時", hours)
                            )
                        }

                        // 排程日期
                        if let planned = task.plannedDate {
                            InfoRow(
                                icon: "calendar.badge.clock",
                                iconColor: .orange,
                                title: "排程日期",
                                value: planned.formatDateTime()
                            )

                            if task.isDateLocked {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                    Text("時間已鎖定")
                                        .foregroundColor(.secondary)
                                }
                                .font(.system(size: 13))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }

                        // 描述
                        if let description = task.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                    Text("描述")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.top, 12)

                                Text(description)
                                    .font(.system(size: 15))
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            }
                            .background(Color.appSecondaryBackground.opacity(0.5))
                        }

                        // 創建和更新時間
                        VStack(spacing: 8) {
                            HStack {
                                Text("創建時間")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(task.createdAt.formatDateTime())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("更新時間")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(task.updatedAt.formatDateTime())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }

                    Spacer(minLength: 100)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("任務詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditView = true
                    } label: {
                        Text("編輯")
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        viewModel.deleteTask(task: task)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditTaskView(task: task, viewModel: viewModel)
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - Info Row

@available(iOS 17.0, *)
struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Date Extension

extension Date {
    func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
}
