import SwiftUI

// MARK: - Task Detail View
struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(task: Task) {
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(task: task))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Title Section
                        TitleSection(
                            title: $viewModel.editedTask.title,
                            isEditing: viewModel.isEditing
                        )

                        // Priority & Category
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("優先度")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if viewModel.isEditing {
                                        PriorityPicker(priority: $viewModel.editedTask.priority)
                                    } else {
                                        GlassBadge(
                                            text: viewModel.task.priority.rawValue,
                                            color: priorityColor(viewModel.task.priority),
                                            icon: "flag.fill"
                                        )
                                    }
                                }

                                Divider()

                                HStack {
                                    Text("分類")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if viewModel.isEditing {
                                        CategoryPicker(
                                            category: $viewModel.editedTask.category,
                                            excludeSchool: !viewModel.canUseSchoolCategory
                                        )
                                    } else {
                                        Text(categoryText(viewModel.task.category))
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }

                        // Deadline & Planned Date
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("截止日期")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if viewModel.isEditing {
                                        DatePicker(
                                            "",
                                            selection: Binding(
                                                get: { viewModel.editedTask.deadlineAt ?? Date() },
                                                set: { viewModel.editedTask.deadlineAt = $0 }
                                            ),
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                        .labelsHidden()
                                    } else if let deadline = viewModel.task.deadlineAt {
                                        Text(DateUtils.formatDisplayDateTime(deadline))
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("無")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider()

                                HStack {
                                    Text("排程日期")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let planned = viewModel.task.plannedWorkDate {
                                        Text(DateUtils.formatDisplayDate(planned))
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("未排程")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if viewModel.task.isDateLocked {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                        Text("日期已鎖定")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.orange)
                                }
                            }
                        }

                        // Effort
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("預估時間")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if viewModel.isEditing {
                                        HStack {
                                            TextField("", value: $viewModel.editedTask.estimatedEffortMin, format: .number)
                                                .textFieldStyle(.roundedBorder)
                                                .keyboardType(.numberPad)
                                                .frame(width: 80)
                                            Text("分鐘")
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("\(viewModel.task.estimatedEffortMin) 分鐘")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    }
                                }

                                if let actualMin = viewModel.task.actualWorkMin, actualMin > 0 {
                                    Divider()
                                    HStack {
                                        Text("實際時間")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(actualMin) 分鐘")
                                            .font(.system(size: 14))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }

                        // Description
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("說明")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                if viewModel.isEditing {
                                    TextEditor(text: $viewModel.editedTask.description)
                                        .frame(minHeight: 100)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                } else if !viewModel.task.description.isEmpty {
                                    Text(viewModel.task.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("無說明")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Focus & Actions
                        if !viewModel.isEditing {
                            GlassCard {
                                VStack(spacing: 12) {
                                    Button(action: { Task { await viewModel.toggleFocus() } }) {
                                        HStack {
                                            Image(systemName: viewModel.task.isTodayFocus ? "star.fill" : "star")
                                                .foregroundColor(.yellow)
                                            Text(viewModel.task.isTodayFocus ? "取消焦點" : "設為焦點")
                                                .font(.system(size: 16, weight: .medium))
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.yellow.opacity(0.1))
                                        .cornerRadius(12)
                                    }

                                    if viewModel.task.state == .open {
                                        Button(action: { Task { await viewModel.startFocus() } }) {
                                            HStack {
                                                Image(systemName: "timer")
                                                    .foregroundColor(.blue)
                                                Text("開始專注")
                                                    .font(.system(size: 16, weight: .medium))
                                                Spacer()
                                            }
                                            .padding()
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }

                        // Dependencies
                        if !viewModel.task.blockedByTaskIds.isEmpty || !viewModel.task.blockingTaskIds.isEmpty {
                            DependenciesSection(
                                blockedBy: viewModel.blockedByTasks,
                                blocking: viewModel.blockingTasks
                            )
                        }

                        // Evidences
                        EvidencesSection(
                            evidences: viewModel.task.evidences,
                            onAdd: { viewModel.showAddEvidence = true },
                            onDelete: { evidence in
                                Task { await viewModel.deleteEvidence(evidence) }
                            }
                        )

                        // Delete Button
                        if !viewModel.isEditing && viewModel.task.state == .open {
                            Button(action: { viewModel.showDeleteConfirm = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("刪除任務")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("任務詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.isEditing ? "取消" : "關閉") {
                        if viewModel.isEditing {
                            viewModel.cancelEdit()
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isEditing {
                        Button("儲存") {
                            Task {
                                await viewModel.saveChanges()
                                dismiss()
                            }
                        }
                    } else if viewModel.task.state == .open {
                        Button("編輯") {
                            viewModel.startEdit()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddEvidence) {
            AddEvidenceSheet(onSave: { evidence in
                Task { await viewModel.addEvidence(evidence) }
            })
        }
        .alert("刪除任務", isPresented: $viewModel.showDeleteConfirm) {
            Button("刪除", role: .destructive) {
                Task {
                    await viewModel.deleteTask()
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("確定要刪除這個任務嗎？此操作無法復原。")
        }
        .fullScreenCover(isPresented: $viewModel.showFocusMode) {
            FocusModeView(task: viewModel.task)
        }
        .task {
            await viewModel.loadDependencies()
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .P0: return .red
        case .P1: return .orange
        case .P2: return .blue
        case .P3: return .gray
        }
    }

    private func categoryText(_ category: TaskCategory) -> String {
        switch category {
        case .school: return "學校"
        case .work: return "工作"
        case .personal: return "個人"
        case .other: return "其他"
        }
    }
}

// MARK: - Title Section
struct TitleSection: View {
    @Binding var title: String
    let isEditing: Bool

    var body: some View {
        GlassCard {
            if isEditing {
                TextField("任務標題", text: $title)
                    .font(.system(size: 20, weight: .bold))
                    .textFieldStyle(.plain)
            } else {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Dependencies Section
struct DependenciesSection: View {
    let blockedBy: [Task]
    let blocking: [Task]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("依賴關係")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                if !blockedBy.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                            Text("被這些任務阻擋：")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.orange)

                        ForEach(blockedBy) { task in
                            HStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                if !blocking.isEmpty {
                    if !blockedBy.isEmpty {
                        Divider()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                            Text("阻擋這些任務：")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)

                        ForEach(blocking) { task in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Evidences Section
struct EvidencesSection: View {
    let evidences: [TaskEvidence]
    let onAdd: () -> Void
    let onDelete: (TaskEvidence) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("證據/作品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }

                if evidences.isEmpty {
                    Text("尚未添加任何證據")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(evidences) { evidence in
                        EvidenceRow(evidence: evidence, onDelete: { onDelete(evidence) })
                    }
                }
            }
        }
    }
}

struct EvidenceRow: View {
    let evidence: TaskEvidence
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: evidenceIcon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(evidence.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                if let url = evidence.url {
                    Link(url, destination: URL(string: url)!)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var evidenceIcon: String {
        switch evidence.type {
        case .link: return "link"
        case .file: return "doc.fill"
        case .note: return "note.text"
        }
    }
}

// MARK: - Add Evidence Sheet
struct AddEvidenceSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (TaskEvidence) -> Void

    @State private var type: TaskEvidence.EvidenceType = .link
    @State private var title = ""
    @State private var url = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("類型")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                Picker("", selection: $type) {
                                    Text("連結").tag(TaskEvidence.EvidenceType.link)
                                    Text("筆記").tag(TaskEvidence.EvidenceType.note)
                                }
                                .pickerStyle(.segmented)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("標題")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    TextField("例如：報告文件", text: $title)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Divider()

                                if type == .link {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("連結")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)

                                        TextField("https://...", text: $url)
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.URL)
                                            .textInputAutocapitalization(.never)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("內容")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)

                                        TextEditor(text: $note)
                                            .frame(minHeight: 100)
                                            .scrollContentBackground(.hidden)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("新增證據")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let evidence = TaskEvidence(
                            type: type,
                            title: title,
                            url: type == .link ? url : nil,
                            note: type == .note ? note : nil
                        )
                        onSave(evidence)
                        dismiss()
                    }
                    .disabled(title.isEmpty || (type == .link && url.isEmpty) || (type == .note && note.isEmpty))
                }
            }
        }
    }
}
