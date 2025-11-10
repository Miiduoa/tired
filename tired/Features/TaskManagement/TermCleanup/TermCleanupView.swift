import SwiftUI

// MARK: - Term Cleanup View
struct TermCleanupView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel: TermCleanupViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: TermCleanupViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.purple.opacity(0.15), .blue.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView(message: "載入任務...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 60))
                                    .foregroundColor(.purple)

                                Text("學期切換")
                                    .font(.system(size: 28, weight: .bold))

                                if let previousTerm = viewModel.previousTermId,
                                   let currentTerm = viewModel.currentTermId {
                                    Text("從 \(previousTerm) 切換到 \(currentTerm)")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 40)

                            // Old Term Tasks Summary
                            if !viewModel.oldTermTasks.isEmpty {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text("上學期遺留任務")
                                                .font(.system(size: 18, weight: .semibold))
                                            Spacer()
                                            Text("\(viewModel.oldTermTasks.count) 個")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.orange)
                                        }

                                        Text("這些任務屬於上一個學期，請選擇處理方式")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            // Cleanup Options
                            VStack(spacing: 12) {
                                Text("清理選項")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                // Auto Complete All
                                GlassCard {
                                    Button(action: {
                                        Task {
                                            await viewModel.autoCompleteAllOldTasks()
                                            await completeCleanup()
                                        }
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.green)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("自動完成全部")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                Text("將所有舊學期任務標記為已完成")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .disabled(viewModel.isProcessing)
                                }

                                // Carry Forward High Priority
                                GlassCard {
                                    Button(action: {
                                        Task {
                                            await viewModel.carryForwardHighPriority()
                                            await completeCleanup()
                                        }
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("帶入高優先級")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                Text("P0/P1 任務保留，其餘完成")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .disabled(viewModel.isProcessing)
                                }

                                // Manual Review
                                GlassCard {
                                    Button(action: {
                                        Task {
                                            await completeCleanup()
                                        }
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "hand.raised.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.purple)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("手動檢視")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                Text("保留所有任務，稍後手動處理")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .disabled(viewModel.isProcessing)
                                }
                            }

                            // Warning Note
                            GlassCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))

                                    Text("提示：學期切換後，建議定期清理舊任務以保持任務列表整潔。你可以稍後在 Backlog 中查看所有任務。")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                    }
                }

                if viewModel.isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("處理中...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("學期切換")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.loadOldTermTasks()
        }
    }

    private func completeCleanup() async {
        await appCoordinator.markTermCleanupHandled()
        ToastManager.shared.showSuccess("學期清理完成")
        dismiss()
    }
}

// MARK: - Term Cleanup View Model
@MainActor
class TermCleanupViewModel: ObservableObject {
    @Published var oldTermTasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var isProcessing: Bool = false

    var previousTermId: String?
    var currentTermId: String?

    private let taskService = TaskService.shared
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared

    func loadOldTermTasks() async {
        isLoading = true

        do {
            guard let userId = FirebaseService.shared.currentUser?.uid else {
                isLoading = false
                return
            }

            // Get profile
            guard let profile = try await profileService.getProfile(userId: userId) else {
                isLoading = false
                return
            }

            previousTermId = profile.previousTermId
            currentTermId = profile.currentTermId

            // Get previous term
            guard let prevTermId = profile.previousTermId,
                  let previousTerm = try await termService.getTermByTermId(userId: userId, termId: prevTermId) else {
                isLoading = false
                return
            }

            // Get all open tasks that belong to previous term
            let allTasks = try await taskService.getTasks(userId: userId)
            oldTermTasks = allTasks.filter { task in
                guard task.state == .open, task.deletedAt == nil else {
                    return false
                }

                // Check if task belongs to previous term
                if let termId = task.termId {
                    return termId == prevTermId
                }

                // Check if task was created during previous term
                if let createdAt = task.createdAt as Date?,
                   let termStart = previousTerm.startDate,
                   let termEnd = previousTerm.endDate {
                    return createdAt >= termStart && createdAt <= termEnd
                }

                return false
            }

        } catch {
            print("❌ Error loading old term tasks: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func autoCompleteAllOldTasks() async {
        isProcessing = true

        for task in oldTermTasks {
            do {
                try await taskService.completeTask(task)
            } catch {
                print("❌ Error completing task: \(error.localizedDescription)")
            }
        }

        isProcessing = false
    }

    func carryForwardHighPriority() async {
        isProcessing = true

        guard let userId = FirebaseService.shared.currentUser?.uid,
              let profile = try? await profileService.getProfile(userId: userId),
              let currentTerm = try? await termService.getTermByTermId(userId: userId, termId: profile.currentTermId ?? "") else {
            isProcessing = false
            return
        }

        for var task in oldTermTasks {
            if task.priority == .P0 || task.priority == .P1 {
                // Carry forward - update term ID
                task.termId = currentTerm.termId
                do {
                    try await taskService.updateTask(task)
                } catch {
                    print("❌ Error carrying forward task: \(error.localizedDescription)")
                }
            } else {
                // Complete low priority tasks
                do {
                    try await taskService.completeTask(task)
                } catch {
                    print("❌ Error completing task: \(error.localizedDescription)")
                }
            }
        }

        isProcessing = false
    }
}

// MARK: - Preview
struct TermCleanupView_Previews: PreviewProvider {
    static var previews: some View {
        TermCleanupView()
            .environmentObject(AppCoordinator())
    }
}
