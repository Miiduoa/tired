import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: viewModel.progress)
                    .tint(.blue)
                    .padding(.horizontal)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    WelcomeStep()
                        .tag(OnboardingStep.welcome)

                    UserStatusStep(selectedStatus: $viewModel.userStatus)
                        .tag(OnboardingStep.userStatus)

                    if viewModel.userStatus == .currentStudent {
                        TermSetupStep(
                            year: $viewModel.termYear,
                            semester: $viewModel.termSemester,
                            startDate: $viewModel.termStartDate,
                            endDate: $viewModel.termEndDate
                        )
                        .tag(OnboardingStep.termSetup)
                    }

                    CapacitySetupStep(
                        weekdayCapacity: $viewModel.weekdayCapacity,
                        weekendCapacity: $viewModel.weekendCapacity
                    )
                    .tag(OnboardingStep.capacitySetup)

                    CompletionStep()
                        .tag(OnboardingStep.completion)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Buttons
                HStack(spacing: 16) {
                    if viewModel.canGoBack {
                        GlassButton("上一步", icon: "chevron.left", style: .secondary) {
                            viewModel.previousStep()
                        }
                    }

                    Spacer()

                    if viewModel.isLastStep {
                        GlassButton("開始使用", icon: "checkmark.circle.fill", style: .primary) {
                            Task {
                                await viewModel.completeOnboarding(userId: appCoordinator.userId!)
                                appCoordinator.checkOnboardingStatus()
                            }
                        }
                    } else if viewModel.canGoNext {
                        GlassButton("下一步", icon: "chevron.right", style: .primary) {
                            viewModel.nextStep()
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("歡迎使用 Tired")
                    .font(.system(size: 32, weight: .bold))

                Text("大學生任務中樞\n自動長出可驗證的經歷線")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - User Status Step
struct UserStatusStep: View {
    @Binding var selectedStatus: UserStatus?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("你現在的狀態？")
                    .font(.system(size: 28, weight: .bold))

                Text("這會幫助我們為你客製化體驗")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 16) {
                ForEach(UserStatus.allCases, id: \.self) { status in
                    StatusOptionCard(
                        status: status,
                        isSelected: selectedStatus == status,
                        onTap: { selectedStatus = status }
                    )
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct StatusOptionCard: View {
    let status: UserStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(status.displayText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(statusDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var statusDescription: String {
        switch status {
        case .currentStudent:
            return "我會顯示學期、課程等功能"
        case .preparingExam:
            return "專注於考試準備模式"
        case .graduated:
            return "使用個人任務管理功能"
        }
    }
}

// MARK: - Term Setup Step
struct TermSetupStep: View {
    @Binding var year: String
    @Binding var semester: String
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("設定學期")
                        .font(.system(size: 28, weight: .bold))

                    Text("告訴我們這學期的基本資訊")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("學年度")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("例如: 113", text: $year)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("學期")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach(["1", "2"], id: \.self) { sem in
                                    Button(action: { semester = sem }) {
                                        Text("第\(sem)學期")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(semester == sem ? .white : .primary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(semester == sem ? Color.blue : Color.gray.opacity(0.2))
                                            )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("學期開始日期")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("學期結束日期")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Capacity Setup Step
struct CapacitySetupStep: View {
    @Binding var weekdayCapacity: Int
    @Binding var weekendCapacity: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("設定讀書容量")
                        .font(.system(size: 28, weight: .bold))

                    Text("每天你大概有多少時間可以做任務？")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                GlassCard {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("平日")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("\(weekdayCapacity / 60)小時 \(weekdayCapacity % 60)分鐘")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(weekdayCapacity) },
                                    set: { weekdayCapacity = Int($0) }
                                ),
                                in: 0...480,
                                step: 30
                            )
                            .tint(.blue)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("週末")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("\(weekendCapacity / 60)小時 \(weekendCapacity % 60)分鐘")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(weekendCapacity) },
                                    set: { weekendCapacity = Int($0) }
                                ),
                                in: 0...480,
                                step: 30
                            )
                            .tint(.blue)
                        }
                    }
                }

                Text("💡 之後可以在設定中修改")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Completion Step
struct CompletionStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("準備完成！")
                    .font(.system(size: 32, weight: .bold))

                Text("讓我們開始管理你的任務吧")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
