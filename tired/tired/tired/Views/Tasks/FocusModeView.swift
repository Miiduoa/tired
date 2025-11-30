import SwiftUI
import UIKit
import Combine

/// 專注模式視圖 - 番茄鐘功能
@available(iOS 17.0, *)
struct FocusModeView: View {
    @Binding var task: Task
    @Environment(\.dismiss) private var dismiss
    
    @State private var timeRemaining: TimeInterval = 25 * 60 // 25分鐘
    @State private var totalTime: TimeInterval = 25 * 60
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var sessionsCompleted = 0
    @State private var totalFocusedMinutes = 0 // 本次專注總分鐘數
    @State private var sessionStartTime: Date? = nil
    @State private var isBreakTime = false
    @State private var showingSettings = false
    @State private var showingStats = false
    @State private var focusDuration: Int = 25
    @State private var breakDuration: Int = 5
    @State private var longBreakDuration: Int = 15
    @State private var sessionsUntilLongBreak: Int = 4
    
    @AppStorage("totalLifetimeFocusMinutes") private var totalLifetimeFocusMinutes = 0
    @AppStorage("totalFocusSessions") private var totalFocusSessions = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let taskService = TaskService()
    
    var body: some View {
        ZStack {
            // 背景
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // 頂部控制
                HStack {
                    Button {
                        saveSessionAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // 統計按鈕
                    Button {
                        showingStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 任務標題
                VStack(spacing: 8) {
                    Text(isBreakTime ? "休息時間" : "專注中")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(task.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                }
                
                // 計時器圓環
                ZStack {
                    // 背景圓環
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 260, height: 260)
                    
                    // 進度圓環
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isBreakTime ? Color.green : Color.white,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    // 時間顯示
                    VStack(spacing: 8) {
                        Text(formattedTime)
                            .font(.system(size: 64, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Text("第 \(sessionsCompleted + 1) 個專注時段")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 32)
                
                // 控制按鈕
                HStack(spacing: 32) {
                    // 重置按鈕
                    Button {
                        resetTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // 播放/暫停按鈕
                    Button {
                        toggleTimer()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(isBreakTime ? .green : AppDesignSystem.accentColor)
                            .frame(width: 80, height: 80)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    }
                    
                    // 跳過按鈕
                    Button {
                        skipToNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                // 統計資訊
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(sessionsCompleted)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("完成時段")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(totalFocusedMinutes)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("專注分鐘")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                // 完成按鈕
                Button {
                    completeSession()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("完成任務")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
                }
                .padding(.bottom, 32)
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                handleTimerComplete()
            }
        }
        .sheet(isPresented: $showingSettings) {
            FocusSettingsSheet(
                focusDuration: $focusDuration,
                breakDuration: $breakDuration,
                longBreakDuration: $longBreakDuration,
                sessionsUntilLongBreak: $sessionsUntilLongBreak,
                onApply: {
                    resetTimer()
                }
            )
        }
        .sheet(isPresented: $showingStats) {
            FocusStatsSheet(
                currentSessionMinutes: totalFocusedMinutes,
                currentSessionCount: sessionsCompleted,
                lifetimeMinutes: totalLifetimeFocusMinutes,
                lifetimeSessions: totalFocusSessions
            )
        }
        .onAppear {
            // 設定螢幕常亮
            UIApplication.shared.isIdleTimerDisabled = true
            sessionStartTime = Date()
        }
        .onDisappear {
            // 恢復螢幕自動關閉
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return timeRemaining / totalTime
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: isBreakTime ?
                [Color(red: 0.2, green: 0.5, blue: 0.3), Color(red: 0.1, green: 0.3, blue: 0.2)] :
                [Color(red: 0.1, green: 0.2, blue: 0.4), Color(red: 0.05, green: 0.1, blue: 0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Actions
    
    private func toggleTimer() {
        if isRunning {
            isRunning = false
            isPaused = true
        } else {
            isRunning = true
            isPaused = false
        }
        
        // 觸覺反饋
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func resetTimer() {
        isRunning = false
        isPaused = false
        if isBreakTime {
            let breakLength = (sessionsCompleted + 1) % sessionsUntilLongBreak == 0 ? longBreakDuration : breakDuration
            timeRemaining = TimeInterval(breakLength * 60)
            totalTime = timeRemaining
        } else {
            timeRemaining = TimeInterval(focusDuration * 60)
            totalTime = timeRemaining
        }
    }
    
    private func skipToNext() {
        handleTimerComplete()
    }
    
    private func handleTimerComplete() {
        isRunning = false
        
        // 觸覺反饋
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if isBreakTime {
            // 休息結束，開始下一個專注時段
            isBreakTime = false
            timeRemaining = TimeInterval(focusDuration * 60)
            totalTime = timeRemaining
        } else {
            // 專注結束，增加完成計數並開始休息
            sessionsCompleted += 1
            totalFocusedMinutes += focusDuration
            
            // 更新全局統計
            totalLifetimeFocusMinutes += focusDuration
            totalFocusSessions += 1
            
            isBreakTime = true
            
            let breakLength = sessionsCompleted % sessionsUntilLongBreak == 0 ? longBreakDuration : breakDuration
            timeRemaining = TimeInterval(breakLength * 60)
            totalTime = timeRemaining
            
            ToastManager.shared.showToast(
                message: "🎯 專注時段完成！休息 \(breakLength) 分鐘",
                type: .success
            )
        }
    }
    
    private func completeSession() {
        // 保存專注記錄到任務
        saveFocusSession()
        
        // 標記任務完成
        task.isDone = true
        task.doneAt = Date()
        
        ToastManager.shared.showToast(
            message: "🎉 任務完成！共專注 \(totalFocusedMinutes) 分鐘",
            type: .success
        )
        
        dismiss()
    }
    
    private func saveSessionAndDismiss() {
        // 計算當前進行中但未完成的時間
        if isRunning && !isBreakTime {
            let elapsedMinutes = Int(totalTime - timeRemaining) / 60
            if elapsedMinutes > 0 {
                totalFocusedMinutes += elapsedMinutes
                totalLifetimeFocusMinutes += elapsedMinutes
            }
        }
        
        // 保存專注記錄
        if totalFocusedMinutes > 0 {
            saveFocusSession()
        }
        
        dismiss()
    }
    
    private func saveFocusSession() {
        // 創建專注記錄
        let session = FocusSession(
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            durationMinutes: totalFocusedMinutes,
            breakMinutes: sessionsCompleted * breakDuration,
            isCompleted: true,
            notes: "完成 \(sessionsCompleted) 個專注時段"
        )
        
        // 更新任務的專注記錄
        if task.focusSessions == nil {
            task.focusSessions = []
        }
        task.focusSessions?.append(session)
        task.totalFocusMinutes = (task.totalFocusMinutes ?? 0) + totalFocusedMinutes
        
        // 異步保存到資料庫
        _Concurrency.Task {
            do {
                try await taskService.updateTask(task)
            } catch {
                print("❌ Failed to save focus session: \(error)")
            }
        }
    }
}

// MARK: - 專注設置 Sheet
@available(iOS 17.0, *)
struct FocusSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var focusDuration: Int
    @Binding var breakDuration: Int
    @Binding var longBreakDuration: Int
    @Binding var sessionsUntilLongBreak: Int
    
    let onApply: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("專注時間") {
                    Stepper("\(focusDuration) 分鐘", value: $focusDuration, in: 5...60, step: 5)
                }
                
                Section("短休息") {
                    Stepper("\(breakDuration) 分鐘", value: $breakDuration, in: 1...15)
                }
                
                Section("長休息") {
                    Stepper("\(longBreakDuration) 分鐘", value: $longBreakDuration, in: 10...30, step: 5)
                    
                    Stepper("每 \(sessionsUntilLongBreak) 個時段", value: $sessionsUntilLongBreak, in: 2...6)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("番茄鐘技巧")
                            .font(.headline)
                        Text("經典的番茄工作法建議 25 分鐘專注 + 5 分鐘休息。每完成 4 個時段後，享受一次較長的休息。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("專注設置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 專注統計 Sheet
@available(iOS 17.0, *)
struct FocusStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentSessionMinutes: Int
    let currentSessionCount: Int
    let lifetimeMinutes: Int
    let lifetimeSessions: Int
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 本次專注統計
                    VStack(alignment: .leading, spacing: 16) {
                        Text("本次專注")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            StatBox(
                                value: "\(currentSessionMinutes)",
                                label: "分鐘",
                                icon: "clock.fill",
                                color: .blue
                            )
                            
                            StatBox(
                                value: "\(currentSessionCount)",
                                label: "時段",
                                icon: "timer",
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    .glassmorphicCard()
                    
                    // 累計統計
                    VStack(alignment: .leading, spacing: 16) {
                        Text("累計成就")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            StatBox(
                                value: formatTime(lifetimeMinutes),
                                label: "總專注時間",
                                icon: "hourglass.circle.fill",
                                color: .purple
                            )
                            
                            StatBox(
                                value: "\(lifetimeSessions)",
                                label: "完成時段",
                                icon: "checkmark.seal.fill",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .glassmorphicCard()
                    
                    // 成就徽章
                    VStack(alignment: .leading, spacing: 16) {
                        Text("專注成就")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                            AchievementBadge(
                                icon: "flame.fill",
                                title: "初次專注",
                                isUnlocked: lifetimeSessions >= 1,
                                color: .orange
                            )
                            
                            AchievementBadge(
                                icon: "star.fill",
                                title: "專注新手",
                                isUnlocked: lifetimeSessions >= 10,
                                color: .yellow
                            )
                            
                            AchievementBadge(
                                icon: "bolt.fill",
                                title: "專注達人",
                                isUnlocked: lifetimeSessions >= 50,
                                color: .blue
                            )
                            
                            AchievementBadge(
                                icon: "crown.fill",
                                title: "專注大師",
                                isUnlocked: lifetimeMinutes >= 1000,
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .glassmorphicCard()
                }
                .padding()
            }
            .navigationTitle("專注統計")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)時\(mins)分" : "\(hours)小時"
        }
    }
}

@available(iOS 17.0, *)
private struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
private struct AchievementBadge: View {
    let icon: String
    let title: String
    let isUnlocked: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? color : .gray.opacity(0.4))
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - 專注模式入口按鈕
@available(iOS 17.0, *)
struct FocusModeButton: View {
    @Binding var task: Task
    @State private var showingFocusMode = false
    
    var body: some View {
        Button {
            showingFocusMode = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("專注")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppDesignSystem.accentGradient)
            .cornerRadius(20)
        }
        .fullScreenCover(isPresented: $showingFocusMode) {
            FocusModeView(task: $task)
        }
    }
}
