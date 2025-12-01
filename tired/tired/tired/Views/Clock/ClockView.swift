import SwiftUI
import Combine
import FirebaseAuth

/// 打卡視圖 - Moodle 風格的時間追蹤
@available(iOS 17.0, *)
struct ClockView: View {
    @StateObject private var viewModel = ClockViewModel()
    @State private var showingClockInSheet = false
    @State private var showingStatistics = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 當前打卡狀態卡片
                        currentClockCard

                        // 今日統計卡片
                        todayStatisticsCard

                        // 打卡歷史
                        if !viewModel.clockRecords.isEmpty {
                            clockHistorySection
                        }
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
            .navigationTitle("打卡")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingStatistics = true
                    }) {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $showingClockInSheet) {
                ClockInSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingStatistics) {
                ClockStatisticsSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadClockRecords()
                viewModel.checkActiveRecord()
            }
        }
    }

    // MARK: - Subviews

    private var currentClockCard: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            if let activeRecord = viewModel.activeRecord {
                // 進行中的打卡
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("進行中")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.green)

                            Text("已工作")
                                .font(AppDesignSystem.bodyFont.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(viewModel.currentDuration)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        if let description = activeRecord.workDescription {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.secondary)
                                Text(description)
                                    .font(AppDesignSystem.bodyFont)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.secondary)
                            Text("開始於 \(activeRecord.clockInTime.formatTime())")
                                .font(AppDesignSystem.bodyFont)
                        }

                        if let category = activeRecord.category {
                            HStack(spacing: 8) {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.secondary)
                                Text(category)
                                    .font(AppDesignSystem.bodyFont)
                            }
                        }
                    }

                    Button(action: {
                        _Concurrency.Task {
                            await viewModel.clockOut()
                        }
                    }) {
                        HStack {
                            Image(systemName: "clock.badge.checkmark.fill")
                            Text("打卡下班")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                    }
                    .disabled(viewModel.isProcessing)
                }
                .padding(AppDesignSystem.paddingMedium)
                .glassmorphicCard()
            } else {
                // 未打卡狀態
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppDesignSystem.accentColor)

                    Text("準備開始工作？")
                        .font(AppDesignSystem.titleFont)
                        .foregroundColor(.primary)

                    Button(action: {
                        showingClockInSheet = true
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("打卡上班")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppDesignSystem.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                    }
                    .disabled(viewModel.isProcessing)
                }
                .padding(AppDesignSystem.paddingLarge)
                .glassmorphicCard()
            }
        }
    }

    private var todayStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日統計")
                .font(AppDesignSystem.bodyFont.weight(.semibold))
                .foregroundColor(.primary)

            HStack(spacing: AppDesignSystem.paddingMedium) {
                StatisticItem(
                    icon: "clock.fill",
                    title: "總工時",
                    value: String(format: "%.1f 小時", viewModel.todayTotalHours),
                    color: .blue
                )

                StatisticItem(
                    icon: "list.bullet",
                    title: "打卡次數",
                    value: "\(viewModel.todayRecordCount) 次",
                    color: .green
                )
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private var clockHistorySection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            Text("打卡歷史")
                .font(AppDesignSystem.bodyFont.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, AppDesignSystem.paddingSmall)

            ForEach(viewModel.clockRecords.prefix(10)) { record in
                ClockRecordRow(record: record)
            }
        }
    }
}

// MARK: - Statistic Item

@available(iOS 17.0, *)
struct StatisticItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)

            Text(value)
                .font(AppDesignSystem.bodyFont.weight(.bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
    }
}

// MARK: - Clock Record Row

@available(iOS 17.0, *)
struct ClockRecordRow: View {
    let record: ClockRecord

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // 時間指示器
            VStack(spacing: 4) {
                Text(record.clockInTime.formatTime())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(record.clockInTime.formatShort())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)

            Divider()
                .frame(height: 40)

            // 記錄詳情
            VStack(alignment: .leading, spacing: 6) {
                if let description = record.workDescription {
                    Text(description)
                        .font(AppDesignSystem.bodyFont.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if let category = record.category {
                        Label(category, systemImage: "tag.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Label(record.formattedDuration, systemImage: "timer")
                        .font(.system(size: 11))
                        .foregroundColor(record.isActive ? .green : .secondary)
                }
            }

            Spacer()

            // 工時徽章
            if !record.isActive {
                Text(String(format: "%.1fh", record.durationInHours))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppDesignSystem.accentColor)
                    .cornerRadius(6)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }
}

// MARK: - Clock In Sheet

@available(iOS 17.0, *)
struct ClockInSheet: View {
    @ObservedObject var viewModel: ClockViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var workDescription = ""
    @State private var selectedCategory = "工作"
    @State private var location = ""

    let categories = ["工作", "學習", "會議", "專案", "其他"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()

                Form {
                    Section {
                        TextField("工作描述（選填）", text: $workDescription)
                    } header: {
                        Text("描述")
                    }

                    Section {
                        Picker("分類", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("分類")
                    }

                    Section {
                        TextField("地點（選填）", text: $location)
                    } header: {
                        Text("地點")
                    }
                }
            }
            .navigationTitle("打卡上班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("打卡") {
                        _Concurrency.Task {
                            await viewModel.clockIn(
                                workDescription: workDescription.isEmpty ? nil : workDescription,
                                location: location.isEmpty ? nil : location,
                                category: selectedCategory
                            )
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class ClockViewModel: ObservableObject {
    @Published var clockRecords: [ClockRecord] = []
    @Published var activeRecord: ClockRecord?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var currentDuration = "00:00:00"

    private let clockService = ClockService()
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    var userId: String? {
        Auth.auth().currentUser?.uid
    }

    var todayTotalHours: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return clockRecords
            .filter { calendar.isDate($0.clockInTime, inSameDayAs: today) }
            .filter { !$0.isActive }
            .reduce(0.0) { $0 + $1.durationInHours }
    }

    var todayRecordCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return clockRecords
            .filter { calendar.isDate($0.clockInTime, inSameDayAs: today) }
            .count
    }

    func loadClockRecords() {
        guard let userId = userId else { return }

        clockService.getUserClockRecords(userId: userId, limit: 50)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "載入打卡記錄失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] records in
                    self?.clockRecords = records
                }
            )
            .store(in: &cancellables)
    }

    func checkActiveRecord() {
        guard let userId = userId else { return }

        _Concurrency.Task {
            do {
                activeRecord = try await clockService.getActiveClockRecord(userId: userId)
                if activeRecord != nil {
                    startDurationTimer()
                }
            } catch {
                print("❌ Error checking active record: \(error)")
            }
        }
    }

    func clockIn(
        workDescription: String? = nil,
        location: String? = nil,
        category: String? = nil
    ) async {
        guard let userId = userId else { return }

        isProcessing = true

        do {
            activeRecord = try await clockService.clockIn(
                userId: userId,
                workDescription: workDescription,
                location: location,
                category: category
            )

            startDurationTimer()
            ToastManager.shared.showToast(message: "打卡成功！", type: .success)
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.showToast(message: "打卡失敗：\(error.localizedDescription)", type: .error)
        }

        isProcessing = false
    }

    func clockOut() async {
        guard let recordId = activeRecord?.id else { return }

        isProcessing = true

        do {
            let completedRecord = try await clockService.clockOut(recordId: recordId)
            activeRecord = nil
            stopDurationTimer()

            ToastManager.shared.showToast(
                message: "打卡下班成功！工作時長：\(completedRecord.formattedDuration)",
                type: .success
            )
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.showToast(message: "打卡下班失敗：\(error.localizedDescription)", type: .error)
        }

        isProcessing = false
    }

    private func startDurationTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentDuration()
        }
    }

    private func stopDurationTimer() {
        timer?.invalidate()
        timer = nil
        currentDuration = "00:00:00"
    }

    private func updateCurrentDuration() {
        guard let clockInTime = activeRecord?.clockInTime else { return }

        let duration = Date().timeIntervalSince(clockInTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        currentDuration = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Clock Statistics Sheet

@available(iOS 17.0, *)
struct ClockStatisticsSheet: View {
    @ObservedObject var viewModel: ClockViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 今日統計
                    ClockStatCard(
                        title: "今日總時數",
                        value: String(format: "%.1f 小時", viewModel.todayTotalHours),
                        icon: "clock.fill"
                    )
                    
                    // 今日打卡次數
                    ClockStatCard(
                        title: "今日打卡次數",
                        value: "\(viewModel.todayRecordCount) 次",
                        icon: "checkmark.circle.fill"
                    )
                }
                .padding()
            }
            .navigationTitle("打卡統計")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ClockStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct ClockView_Previews: PreviewProvider {
    static var previews: some View {
        ClockView()
    }
}
