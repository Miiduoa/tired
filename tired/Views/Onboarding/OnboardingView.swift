import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var taskService: TaskService

    var body: some View {
        ZStack {
            // 漸變背景
            LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.currentStep {
            case .welcome:
                WelcomeStep(viewModel: viewModel)
            case .userStatus:
                UserStatusStep(viewModel: viewModel)
            case .termSetup:
                TermSetupStep(viewModel: viewModel)
            case .capacity:
                CapacityStep(viewModel: viewModel)
            case .complete:
                CompletingStep(viewModel: viewModel, taskService: taskService)
            }
        }
    }
}

// MARK: - ViewModel

class OnboardingViewModel: ObservableObject {
    enum Step {
        case welcome
        case userStatus
        case termSetup
        case capacity
        case complete
    }

    @Published var currentStep: Step = .welcome

    // User status
    @Published var userStatus: UserStatus = .student
    enum UserStatus {
        case student
        case preparing
        case graduated
    }

    // Term setup (for students)
    @Published var academicYear: String = ""
    @Published var semester: String = "1"
    @Published var termStartDate: Date = Date()
    @Published var termEndDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()

    // Capacity
    @Published var weekdayCapacity: Int = 180  // 3 hours
    @Published var weekendCapacity: Int = 240  // 4 hours

    func next() {
        withAnimation {
            switch currentStep {
            case .welcome:
                currentStep = .userStatus
            case .userStatus:
                if userStatus == .student {
                    currentStep = .termSetup
                } else {
                    currentStep = .capacity
                }
            case .termSetup:
                currentStep = .capacity
            case .capacity:
                currentStep = .complete
            case .complete:
                break
            }
        }
    }

    func back() {
        withAnimation {
            switch currentStep {
            case .welcome:
                break
            case .userStatus:
                currentStep = .welcome
            case .termSetup:
                currentStep = .userStatus
            case .capacity:
                currentStep = userStatus == .student ? .termSetup : .userStatus
            case .complete:
                break
            }
        }
    }

    func completeOnboarding(userId: String, taskService: TaskService) {
        // 創建 TermConfig
        let termId: String
        let startDate: Date?
        let endDate: Date?
        let isHoliday: Bool

        if userStatus == .student {
            termId = "\(academicYear)-\(semester)"
            startDate = termStartDate
            endDate = termEndDate
            isHoliday = false
        } else {
            termId = "personal-default"
            startDate = Date()
            endDate = nil
            isHoliday = true
        }

        // 更新 UserProfile
        taskService.updateUserProfile { profile in
            profile.currentTermId = termId
            profile.weekdayCapacityMin = weekdayCapacity
            profile.weekendCapacityMin = weekendCapacity
            profile.lastTermChangeAt = Date()
        }

        // 創建 TermConfig (這裡簡化，實際需要通過 TermConfigService)
        // TODO: Create TermConfig in Firestore
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GlassCard(padding: AppTheme.spacing4) {
            VStack(spacing: AppTheme.spacing3) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("歡迎使用 Tired")
                    .font(AppTheme.titleFont)
                    .foregroundColor(.white)

                Text("大學生任務中樞\n自動長出可驗證的經歷線")
                    .font(AppTheme.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: AppTheme.spacing3)

                Button(action: viewModel.next) {
                    Text("開始設定")
                        .font(AppTheme.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
            }
        }
        .padding(AppTheme.spacing3)
    }
}

// MARK: - User Status Step

struct UserStatusStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: AppTheme.spacing3) {
            GlassCard(padding: AppTheme.spacing3) {
                VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                    Text("你現在的狀態？")
                        .font(AppTheme.headline)

                    StatusOption(
                        title: "在學中",
                        icon: "graduationcap.fill",
                        isSelected: viewModel.userStatus == .student
                    ) {
                        viewModel.userStatus = .student
                    }

                    StatusOption(
                        title: "準備升學 / 考試中",
                        icon: "book.fill",
                        isSelected: viewModel.userStatus == .preparing
                    ) {
                        viewModel.userStatus = .preparing
                    }

                    StatusOption(
                        title: "已畢業 / 先工作一陣子",
                        icon: "briefcase.fill",
                        isSelected: viewModel.userStatus == .graduated
                    ) {
                        viewModel.userStatus = .graduated
                    }
                }
            }

            HStack {
                Button(action: viewModel.back) {
                    Text("上一步")
                        .font(AppTheme.body)
                }
                .secondaryButton()

                Spacer()

                Button(action: viewModel.next) {
                    Text("下一步")
                        .font(AppTheme.subheadline)
                }
                .primaryButton()
            }
        }
        .padding(AppTheme.spacing3)
    }
}

struct StatusOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.primaryColor : AppTheme.textSecondary)

                Text(title)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(AppTheme.spacing2)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isSelected ? AppTheme.primaryColor.opacity(0.1) : Color.clear)
            )
        }
    }
}

// MARK: - Term Setup Step

struct TermSetupStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: AppTheme.spacing3) {
            GlassCard(padding: AppTheme.spacing3) {
                VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                    Text("學期設定")
                        .font(AppTheme.headline)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("學年度")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("例如: 113", text: $viewModel.academicYear)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }

                        VStack(alignment: .leading) {
                            Text("學期")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Picker("學期", selection: $viewModel.semester) {
                                Text("1").tag("1")
                                Text("2").tag("2")
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    DatePicker("開始日期",
                              selection: $viewModel.termStartDate,
                              displayedComponents: .date)
                        .datePickerStyle(.compact)

                    DatePicker("結束日期",
                              selection: $viewModel.termEndDate,
                              displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }

            HStack {
                Button(action: viewModel.back) {
                    Text("上一步")
                        .font(AppTheme.body)
                }
                .secondaryButton()

                Spacer()

                Button(action: viewModel.next) {
                    Text("下一步")
                        .font(AppTheme.subheadline)
                }
                .primaryButton()
                .disabled(viewModel.academicYear.isEmpty)
            }
        }
        .padding(AppTheme.spacing3)
    }
}

// MARK: - Capacity Step

struct CapacityStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: AppTheme.spacing3) {
            GlassCard(padding: AppTheme.spacing3) {
                VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                    Text("每日可用時間")
                        .font(AppTheme.headline)

                    Text("設定你每天大概有多少時間可以做任務")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                        Text("平日：\(viewModel.weekdayCapacity / 60) 小時 \(viewModel.weekdayCapacity % 60) 分鐘")
                            .font(AppTheme.body)

                        Slider(value: Binding(
                            get: { Double(viewModel.weekdayCapacity) },
                            set: { viewModel.weekdayCapacity = Int($0) }
                        ), in: 60...480, step: 30)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacing2) {
                        Text("週末：\(viewModel.weekendCapacity / 60) 小時 \(viewModel.weekendCapacity % 60) 分鐘")
                            .font(AppTheme.body)

                        Slider(value: Binding(
                            get: { Double(viewModel.weekendCapacity) },
                            set: { viewModel.weekendCapacity = Int($0) }
                        ), in: 60...480, step: 30)
                    }
                }
            }

            HStack {
                Button(action: viewModel.back) {
                    Text("上一步")
                        .font(AppTheme.body)
                }
                .secondaryButton()

                Spacer()

                Button(action: viewModel.next) {
                    Text("完成")
                        .font(AppTheme.subheadline)
                }
                .primaryButton()
            }
        }
        .padding(AppTheme.spacing3)
    }
}

// MARK: - Completing Step

struct CompletingStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var taskService: TaskService

    var body: some View {
        GlassCard(padding: AppTheme.spacing4) {
            VStack(spacing: AppTheme.spacing3) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("正在設定...")
                    .font(AppTheme.subheadline)
                    .foregroundColor(.white)
            }
        }
        .padding(AppTheme.spacing3)
        .onAppear {
            // 完成 onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let userId = taskService.userProfile?.userId {
                    viewModel.completeOnboarding(userId: userId, taskService: taskService)
                }
            }
        }
    }
}
