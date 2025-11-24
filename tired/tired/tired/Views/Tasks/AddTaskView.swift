import SwiftUI

@available(iOS 17.0, *)
struct AddTaskView: View {
    @ObservedObject var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .personal
    @State private var priority: TaskPriority = .medium
    @State private var estimatedHours: Double = 1.0
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var hasPlannedDate = false
    @State private var plannedDate = Date()
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // Basic info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("基本資訊")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("任務標題", text: $title)
                                .textFieldStyle(FrostedTextFieldStyle())

                            TextField("描述（選填）", text: $description, axis: .vertical)
                                .textFieldStyle(FrostedTextFieldStyle())
                                .lineLimit(3...6)

                            // Category picker
                            HStack {
                                Text("分類")
                                    .font(AppDesignSystem.bodyFont)
                                Spacer()
                                Menu {
                                    ForEach(TaskCategory.allCases, id: \.self) { cat in
                                        Button {
                                            category = cat
                                        } label: {
                                            HStack {
                                                Circle()
                                                    .fill(Color.forCategory(cat))
                                                    .frame(width: 12, height: 12)
                                                Text(cat.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.forCategory(category))
                                            .frame(width: 12, height: 12)
                                        Text(category.displayName)
                                            .font(AppDesignSystem.bodyFont)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Priority picker
                            HStack {
                                Text("優先級")
                                    .font(AppDesignSystem.bodyFont)
                                Spacer()
                                Picker("", selection: $priority) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Text(p.displayName).tag(p)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // Time section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("時間設定")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            // Estimated time
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("預估時長")
                                    Spacer()
                                    Text("\(formatHours(estimatedHours))")
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                                    .tint(AppDesignSystem.accentColor)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Deadline
                            VStack(spacing: 8) {
                                Toggle("設置截止日期", isOn: $hasDeadline)

                                if hasDeadline {
                                    DatePicker("", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Planned date
                            VStack(spacing: 8) {
                                Toggle("排程到特定日期", isOn: $hasPlannedDate)

                                if hasPlannedDate {
                                    DatePicker("", selection: $plannedDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("標籤")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            // Add tag
                            HStack {
                                TextField("新增標籤", text: $newTag)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addTag()
                                    }

                                Button {
                                    addTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(newTag.isEmpty ? .secondary : AppDesignSystem.accentColor)
                                }
                                .disabled(newTag.isEmpty)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

                            // Tags list
                            if !tags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                                .font(.system(size: 13, weight: .medium))
                                            Button {
                                                tags.removeAll { $0 == tag }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 12))
                                            }
                                        }
                                        .foregroundColor(AppDesignSystem.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppDesignSystem.accentColor.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()
                    }
                    .padding(AppDesignSystem.paddingMedium)
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(title.isEmpty ? .secondary : AppDesignSystem.accentColor)
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60)) 分鐘"
        } else if hours == floor(hours) {
            return "\(Int(hours)) 小時"
        } else {
            return String(format: "%.1f 小時", hours)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func createTask() {
        isCreating = true

        viewModel.createTask(
            title: title,
            description: description.isEmpty ? nil : description,
            category: category,
            priority: priority,
            deadline: hasDeadline ? deadline : nil,
            estimatedMinutes: Int(estimatedHours * 60),
            plannedDate: hasPlannedDate ? plannedDate : nil,
            isDateLocked: hasPlannedDate,
            sourceOrgId: nil
        )

        dismiss()
    }
}
