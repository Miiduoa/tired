import SwiftUI

// MARK: - Focus Mode View
struct FocusModeView: View {
    @StateObject private var viewModel: FocusModeViewModel
    @Environment(\.dismiss) var dismiss

    init(task: Task) {
        _viewModel = StateObject(wrappedValue: FocusModeViewModel(task: task))
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Button(action: {
                        viewModel.showEndConfirm = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    Text(viewModel.isBreak ? "休息時間" : "專注模式")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                // Task Info
                if !viewModel.isBreak {
                    VStack(spacing: 12) {
                        Text(viewModel.task.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if viewModel.pomodoroCount > 0 {
                            Text("第 \(viewModel.pomodoroCount + 1) 個番茄鐘")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                // Timer Circle
                ZStack {
                    // Background Circle
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 280, height: 280)

                    // Progress Circle
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            viewModel.isBreak ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: viewModel.progress)

                    // Time Text
                    VStack(spacing: 8) {
                        Text(viewModel.timeString)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(viewModel.isRunning ? (viewModel.isBreak ? "休息中" : "專注中") : "暫停")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Control Buttons
                HStack(spacing: 40) {
                    // Play/Pause Button
                    Button(action: {
                        viewModel.toggleTimer()
                    }) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(.ultraThickMaterial)
                            )
                    }

                    // Skip Button
                    if viewModel.isBreak {
                        Button(action: {
                            viewModel.skipBreak()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                }

                Spacer()

                // Stats
                HStack(spacing: 40) {
                    StatBubble(
                        value: "\(viewModel.pomodoroCount)",
                        label: "番茄鐘",
                        icon: "timer"
                    )

                    StatBubble(
                        value: "\(viewModel.totalMinutes)",
                        label: "分鐘",
                        icon: "clock.fill"
                    )

                    StatBubble(
                        value: "\(viewModel.breakCount)",
                        label: "休息次數",
                        icon: "cup.and.saucer.fill"
                    )
                }
                .padding(.bottom, 40)
            }
        }
        .alert("結束專注", isPresented: $viewModel.showEndConfirm) {
            Button("繼續", role: .cancel) {}
            Button("結束並儲存", role: .destructive) {
                Task {
                    await viewModel.endFocus()
                    dismiss()
                }
            }
        } message: {
            Text("確定要結束這次專注嗎？已完成的時間會被記錄。")
        }
        .onAppear {
            viewModel.startTimer()
        }
        .onDisappear {
            viewModel.pauseTimer()
        }
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Preview
struct FocusModeView_Previews: PreviewProvider {
    static var previews: some View {
        FocusModeView(task: Task(
            userId: "user1",
            title: "完成作業報告",
            category: .school
        ))
    }
}
