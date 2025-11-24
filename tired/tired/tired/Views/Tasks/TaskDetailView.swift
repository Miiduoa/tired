import SwiftUI
import FirebaseAuth // Needed for current user id

@available(iOS 17.0, *)
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel // This viewModel will manage task updates
    @State var task: Task // Make task @State so comments/attachments can update it
    @State private var deletableCommentIds: Set<String> = []
    @State private var showingEditView = false
    @State private var newCommentText = ""
    @FocusState private var isCommentInputFocused: Bool
    @State private var canAddComment = false // For RBAC
    @State private var showDeleteConfirmation = false // For task deletion
    @State private var canEditTask = false // For RBAC
    @State private var canDeleteTask = false // For RBAC
    @State private var canToggleTaskDone = false // For RBAC
    @State private var organization: Organization?
    private let organizationService = OrganizationService()

    // Initializer to allow injecting the task (or fetching by ID)
    init(viewModel: TasksViewModel, task: Task) {
        self.viewModel = viewModel
        self._task = State(initialValue: task)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesignSystem.paddingMedium) { // Use a general spacing
                // 標題區域
                VStack(alignment: .leading, spacing: 16) {
                    // 狀態指示器
                    HStack {
                        Button {
                            if canToggleTaskDone {
                                viewModel.toggleTaskDone(task: task)
                                self.task.isDone.toggle() // Optimistic UI update
                            } else {
                                ToastManager.shared.showToast(message: "您沒有權限變更任務完成狀態。", type: .error)
                            }
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isDone ? .green : .gray)
                                .font(.system(size: 32))
                        }
                        .disabled(!canToggleTaskDone)

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
                VStack(spacing: AppDesignSystem.paddingSmall) { // Adjusted spacing for info rows
                    // 歸屬
                    if let org = organization {
                        InfoRow(icon: "building.2.fill", iconColor: .blue, title: "歸屬", value: org.name)
                    } else {
                        InfoRow(icon: "person.fill", iconColor: .green, title: "歸屬", value: task.sourceOrgId == nil ? "個人" : "組織任務")
                    }

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
                .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium) // Apply glassmorphic effect to info container
                .padding(.horizontal, AppDesignSystem.paddingMedium)


                // MARK: - File Attachments Section
                if let attachments = task.fileAttachments, !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                        Text("附件")
                            .font(AppDesignSystem.headlineFont)
                            .padding(.horizontal, AppDesignSystem.paddingMedium)

                        ForEach(attachments) { attachment in
                            FileAttachmentRow(attachment: attachment)
                                .padding(.horizontal, AppDesignSystem.paddingMedium)
                        }
                    }
                    .padding(.vertical, AppDesignSystem.paddingSmall)
                }

                // MARK: - Comments Section
                VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                    Text("評論")
                        .font(AppDesignSystem.headlineFont)
                        .padding(.horizontal, AppDesignSystem.paddingMedium)

                    if let comments = task.comments, !comments.isEmpty {
                        ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                            TaskCommentRow(
                                comment: comment,
                                canDelete: deletableCommentIds.contains(comment.id),
                                onDelete: {
                                    let success = await viewModel.deleteComment(from: task, comment: comment)
                                    if success {
                                        self.task.comments?.removeAll(where: { $0.id == comment.id })
                                        deletableCommentIds.remove(comment.id)
                                    }
                                }
                            )
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                        }
                    } else {
                        Text("沒有評論")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                            .padding(AppDesignSystem.paddingMedium)
                            .frame(maxWidth: .infinity)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                            .padding(.horizontal, AppDesignSystem.paddingMedium)
                    }
                    
                    // Comment Input
                    if canAddComment {
                        HStack {
                            TextField("新增評論...", text: $newCommentText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, AppDesignSystem.paddingMedium)
                                .padding(.vertical, AppDesignSystem.paddingSmall)
                                .background(Material.regular)
                                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                                .focused($isCommentInputFocused)
                            
                            Button {
                                addComment()
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .font(.title2)
                                    .foregroundColor(newCommentText.isEmpty ? .secondary : AppDesignSystem.accentColor)
                            }
                            .disabled(newCommentText.isEmpty)
                        }
                        .padding(.horizontal, AppDesignSystem.paddingMedium)
                        .padding(.vertical, AppDesignSystem.paddingSmall)
                    }
                }
                .padding(.vertical, AppDesignSystem.paddingSmall)
                
                Spacer(minLength: 20)
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
                if canEditTask {
                    Button {
                        showingEditView = true
                    } label: {
                        Text("編輯")
                    }
                }
            }

            ToolbarItem(placement: .destructiveAction) {
                if canDeleteTask {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditTaskView(task: $task, viewModel: viewModel)
        }
        .confirmationDialog("刪除任務", isPresented: $showDeleteConfirmation) {
            Button("刪除", role: .destructive) {
                _Concurrency.Task {
                    await viewModel.deleteTask(task: task)
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("您確定要刪除此任務嗎？此操作無法撤銷。")
        }
        .onAppear {
            _Concurrency.Task {
                canAddComment = await viewModel.canAddComment(to: task)
                canEditTask = await viewModel.canEdit(task: task)
                canDeleteTask = await viewModel.canDelete(task: task)
                canToggleTaskDone = await viewModel.canToggleDone(task: task)
                await refreshCommentPermissions()
                if let orgId = task.sourceOrgId {
                    if let org = try? await organizationService.fetchOrganization(id: orgId) {
                        await MainActor.run { organization = org }
                    }
                }
            }
        }
        .onChange(of: task.comments ?? []) { _ in
            _Concurrency.Task { await refreshCommentPermissions() }
        }
    }
    
    private func addComment() {
        guard !newCommentText.isEmpty else { return }
        
        _Concurrency.Task {
            if let newComment = await viewModel.addComment(to: task, content: newCommentText) {
                if task.comments == nil { task.comments = [] }
                task.comments?.append(newComment)
                deletableCommentIds.insert(newComment.id)
                newCommentText = "" // Clear input field
                isCommentInputFocused = false
            }
        }
    }

    private func refreshCommentPermissions() async {
        guard let comments = task.comments else {
            await MainActor.run { deletableCommentIds = [] }
            return
        }
        var allowed = Set<String>()
        for comment in comments {
            let canDelete = await viewModel.canDeleteComment(from: task, comment: comment)
            if canDelete { allowed.insert(comment.id) }
        }
        await MainActor.run { deletableCommentIds = allowed }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - Task Comment Row

@available(iOS 17.0, *)
struct TaskCommentRow: View {
    let comment: TaskComment
    let canDelete: Bool
    var onDelete: (() async -> Void)?
    
    @State private var authorProfile: UserProfile?
    private let userService = UserService()
    
    var body: some View {
        HStack(alignment: .top, spacing: AppDesignSystem.paddingSmall) {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(authorProfile?.name.prefix(1) ?? "?").uppercased())
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                HStack {
                    Text(authorProfile?.name ?? "未知用戶")
                        .font(AppDesignSystem.captionFont.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(comment.createdAt.formatShort())
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if canDelete {
                        Button(role: .destructive) {
                            _Concurrency.Task { await onDelete?() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(comment.content)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
        .onAppear {
            _Concurrency.Task {
                authorProfile = try? await userService.fetchUserProfile(userId: comment.authorUserId)
            }
        }
    }
}


// MARK: - File Attachment Row

@available(iOS 17.0, *)
struct FileAttachmentRow: View {
    let attachment: FileAttachment

    var body: some View {
        HStack {
            Image(systemName: iconForFileType(attachment.fileType))
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(attachment.fileName)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.primary)
                Text("上傳於 \(attachment.uploadedAt.formatShort())")
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Optional: Button to download/view
                                        // Safely unwrap the URL
                                        if let url = URL(string: attachment.fileUrl) {
                                            Link(destination: url) {
                                                Image(systemName: "safari")
                                            }
                                        } else {
                                            Image(systemName: "safari")
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
    }
    
    private func iconForFileType(_ fileType: String) -> String {
        if fileType.hasPrefix("image") {
            return "photo"
        } else if fileType.contains("pdf") {
            return "doc.text.fill"
        } else if fileType.contains("word") {
            return "doc.text.fill"
        } else if fileType.contains("excel") || fileType.contains("spreadsheet") {
            return "tablecells"
        } else if fileType.contains("presentation") {
            return "rectangle.on.rectangle"
        }
        return "doc"
    }
}

// MARK: - Info Row (Moved to TaskDetailView to avoid conflicts)

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

