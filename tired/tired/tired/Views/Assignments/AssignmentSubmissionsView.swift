import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// 作業提交列表視圖 - 教師視角查看學員作業提交狀態
@available(iOS 17.0, *)
struct AssignmentSubmissionsView: View {
    let organizationId: String
    let organizationName: String

    @StateObject private var viewModel = AssignmentSubmissionsViewModel()
    @State private var selectedSubmission: AssignmentSubmission?
    @State private var showingSubmissionDetail = false

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("載入作業中...")
            } else if viewModel.assignments.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 統計摘要
                        summaryCards

                        // 作業列表
                        LazyVStack(spacing: AppDesignSystem.paddingSmall) {
                            ForEach(viewModel.assignments) { assignment in
                                AssignmentCard(assignment: assignment) {
                                    selectedSubmission = AssignmentSubmission(
                                        assignment: assignment,
                                        organizationId: organizationId
                                    )
                                    showingSubmissionDetail = true
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadAssignments(organizationId: organizationId)
                }
            }
        }
        .navigationTitle("作業提交狀態")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _Concurrency.Task {
                await viewModel.loadAssignments(organizationId: organizationId)
            }
        }
        .sheet(isPresented: $showingSubmissionDetail) {
            if let submission = selectedSubmission {
                AssignmentSubmissionDetailView(submission: submission)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppDesignSystem.paddingLarge) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("尚無作業")
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.secondary)

            Text("建立作業後，學員的提交狀態將在此顯示")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            SummaryCard(
                title: "總作業數",
                value: "\(viewModel.assignments.count)",
                icon: "doc.text.fill",
                color: .blue
            )

            SummaryCard(
                title: "待批改",
                value: "\(viewModel.pendingGradingCount)",
                icon: "clock.fill",
                color: .orange
            )

            SummaryCard(
                title: "已批改",
                value: "\(viewModel.gradedCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Assignment Card

struct AssignmentCard: View {
    let assignment: AssignmentWithSubmissions
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                // Header: Title and Due Date
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.task.title)
                            .font(AppDesignSystem.headlineFont)
                            .foregroundColor(.primary)

                        if let deadline = assignment.task.deadlineAt {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text("截止: \(deadline.formatted(date: .abbreviated, time: .shortened))")
                                    .font(AppDesignSystem.captionFont)
                            }
                            .foregroundColor(assignment.isOverdue ? .red : .secondary)
                        }
                    }

                    Spacer()

                    // Status Badge
                    statusBadge
                }

                Divider()

                // Submission Statistics
                HStack(spacing: AppDesignSystem.paddingMedium) {
                    StatItem(
                        icon: "person.2.fill",
                        value: "\(assignment.totalAssignees)",
                        label: "學員"
                    )

                    StatItem(
                        icon: "checkmark.circle.fill",
                        value: "\(assignment.submittedCount)",
                        label: "已提交",
                        color: .green
                    )

                    StatItem(
                        icon: "clock.fill",
                        value: "\(assignment.pendingCount)",
                        label: "待提交",
                        color: .orange
                    )

                    StatItem(
                        icon: "star.fill",
                        value: "\(assignment.gradedCount)",
                        label: "已評分",
                        color: .blue
                    )
                }

                // Progress Bar
                if assignment.totalAssignees > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            Rectangle()
                                .fill(Color.green)
                                .frame(
                                    width: geometry.size.width * CGFloat(assignment.submittedCount) / CGFloat(assignment.totalAssignees),
                                    height: 6
                                )
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)
                }
            }
            .padding()
            .background(Color.appSecondaryBackground)
            .cornerRadius(AppDesignSystem.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                    .stroke(Color.appCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusBadge: some View {
        Group {
            if assignment.isOverdue && assignment.pendingCount > 0 {
                Label("逾期", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            } else if assignment.allSubmitted {
                Label("全部提交", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .secondary

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Assignment Submission Detail View

@available(iOS 17.0, *)
struct AssignmentSubmissionDetailView: View {
    let submission: AssignmentSubmission
    @StateObject private var viewModel = AssignmentSubmissionDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("載入提交詳情中...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
                            // Assignment Info
                            assignmentInfoSection

                            Divider()

                            // Student Submissions List
                            if viewModel.studentSubmissions.isEmpty {
                                Text("尚無學員提交資料")
                                    .font(AppDesignSystem.bodyFont)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(viewModel.studentSubmissions) { studentSub in
                                    StudentSubmissionRow(submission: studentSub)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("提交詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                _Concurrency.Task {
                    await viewModel.loadSubmissions(
                        assignmentId: submission.assignment.task.id ?? "",
                        assigneeIds: submission.assignment.task.assigneeUserIds ?? [],
                        organizationId: submission.organizationId
                    )
                }
            }
        }
    }

    private var assignmentInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(submission.assignment.task.title)
                .font(.title2.bold())

            if let description = submission.assignment.task.description {
                Text(description)
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
            }

            if let deadline = submission.assignment.task.deadlineAt {
                HStack {
                    Image(systemName: "calendar")
                    Text("截止時間: \(deadline.formatted(date: .long, time: .shortened))")
                }
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
    }
}

// MARK: - Student Submission Row

struct StudentSubmissionRow: View {
    let submission: StudentSubmission

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Student Avatar & Name
                if let avatarUrl = submission.student?.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(submission.student?.name.prefix(1).uppercased() ?? "?")
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(submission.student?.name ?? "未知學員")
                        .font(AppDesignSystem.bodyFont.weight(.semibold))

                    if submission.isSubmitted {
                        if let submittedAt = submission.submittedAt {
                            Text("提交於: \(submittedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("尚未提交")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Status Badge
                submissionStatusBadge
            }

            // Submitted Files
            if !submission.fileAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("附件:")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)

                    ForEach(submission.fileAttachments) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            Text(file.fileName)
                                .font(AppDesignSystem.captionFont)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.leading, 48)
            }

            // Grade Info
            if let grade = submission.grade {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("成績: \(grade.rawValue)")
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                }
                .padding(.leading, 48)
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(Color.appCardBorder, lineWidth: 0.5)
        )
    }

    private var submissionStatusBadge: some View {
        Group {
            if let grade = submission.grade {
                Text("已評分")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            } else if submission.isSubmitted {
                Text("待評分")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            } else {
                Text("未提交")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - View Models

@MainActor
class AssignmentSubmissionsViewModel: ObservableObject {
    @Published var assignments: [AssignmentWithSubmissions] = []
    @Published var isLoading = false

    private let db = FirebaseManager.shared.db
    private let userService = UserService()
    private let gradeService = GradeService()

    var pendingGradingCount: Int {
        assignments.reduce(0) { $0 + $1.submittedCount - $1.gradedCount }
    }

    var gradedCount: Int {
        assignments.reduce(0) { $0 + $1.gradedCount }
    }

    func loadAssignments(organizationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch all homework tasks for this organization
            let snapshot = try await db.collection("tasks")
                .whereField("sourceOrgId", isEqualTo: organizationId)
                .whereField("taskType", isEqualTo: TaskType.homework.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let tasks = snapshot.documents.compactMap { doc -> Task? in
                try? doc.data(as: Task.self)
            }

            // For each task, calculate submission statistics
            var enrichedAssignments: [AssignmentWithSubmissions] = []

            for task in tasks {
                let assigneeIds = task.assigneeUserIds ?? []
                let totalAssignees = assigneeIds.count

                // Count submitted tasks
                let submittedSnapshot = try await db.collection("tasks")
                    .whereField("id", isEqualTo: task.id ?? "")
                    .whereField("isDone", isEqualTo: true)
                    .getDocuments()

                let submittedCount = min(submittedSnapshot.documents.count, totalAssignees)

                // Count graded assignments
                let gradedSnapshot = try await db.collection("grades")
                    .whereField("taskId", isEqualTo: task.id ?? "")
                    .whereField("status", isEqualTo: GradeStatus.graded.rawValue)
                    .getDocuments()

                let gradedCount = gradedSnapshot.documents.count

                let assignment = AssignmentWithSubmissions(
                    task: task,
                    totalAssignees: totalAssignees,
                    submittedCount: submittedCount,
                    gradedCount: gradedCount
                )

                enrichedAssignments.append(assignment)
            }

            assignments = enrichedAssignments
        } catch {
            print("❌ Error loading assignments: \(error)")
            ToastManager.shared.showToast(message: "載入作業失敗: \(error.localizedDescription)", type: .error)
        }
    }
}

@MainActor
class AssignmentSubmissionDetailViewModel: ObservableObject {
    @Published var studentSubmissions: [StudentSubmission] = []
    @Published var isLoading = false

    private let db = FirebaseManager.shared.db
    private let userService = UserService()
    private let gradeService = GradeService()

    func loadSubmissions(assignmentId: String, assigneeIds: [String], organizationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch student profiles
            let students = try await userService.fetchUserProfiles(userIds: assigneeIds)

            // For each student, check submission status
            var submissions: [StudentSubmission] = []

            for assigneeId in assigneeIds {
                // Check if student has completed the task
                let taskSnapshot = try await db.collection("tasks")
                    .whereField("userId", isEqualTo: assigneeId)
                    .whereField("id", isEqualTo: assignmentId)
                    .limit(to: 1)
                    .getDocuments()

                let studentTask = taskSnapshot.documents.first.flatMap { try? $0.data(as: Task.self) }

                // Fetch grade if exists
                let gradeSnapshot = try await db.collection("grades")
                    .whereField("studentId", isEqualTo: assigneeId)
                    .whereField("taskId", isEqualTo: assignmentId)
                    .limit(to: 1)
                    .getDocuments()

                let grade = gradeSnapshot.documents.first.flatMap { try? $0.data(as: Grade.self) }

                let submission = StudentSubmission(
                    student: students[assigneeId],
                    isSubmitted: studentTask?.isDone ?? false,
                    submittedAt: studentTask?.doneAt,
                    fileAttachments: studentTask?.fileAttachments ?? [],
                    grade: grade?.grade
                )

                submissions.append(submission)
            }

            // Sort: submitted first, then by name
            submissions.sort(by: { sub1, sub2 in
                if sub1.isSubmitted != sub2.isSubmitted {
                    return sub1.isSubmitted
                }
                return (sub1.student?.name ?? "") < (sub2.student?.name ?? "")
            })

            studentSubmissions = submissions
        } catch {
            print("❌ Error loading submissions: \(error)")
            ToastManager.shared.showToast(message: "載入提交詳情失敗: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Models

struct AssignmentWithSubmissions: Identifiable {
    let task: Task
    let totalAssignees: Int
    let submittedCount: Int
    let gradedCount: Int

    var id: String { task.id ?? UUID().uuidString }

    var pendingCount: Int {
        totalAssignees - submittedCount
    }

    var allSubmitted: Bool {
        totalAssignees > 0 && submittedCount == totalAssignees
    }

    var isOverdue: Bool {
        guard let deadline = task.deadlineAt else { return false }
        return deadline < Date()
    }
}

struct AssignmentSubmission {
    let assignment: AssignmentWithSubmissions
    let organizationId: String
}

struct StudentSubmission: Identifiable {
    let student: UserProfile?
    let isSubmitted: Bool
    let submittedAt: Date?
    let fileAttachments: [FileAttachment]
    let grade: LetterGrade?

    var id: String { student?.id ?? UUID().uuidString }
}
