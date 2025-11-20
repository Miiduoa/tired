import SwiftUI

@available(iOS 17.0, *)
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSettings = false
    @State private var showingEditProfile = false

    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    if let profile = authService.userProfile {
                        HStack(spacing: 16) {
                            // Avatar
                            if let avatarUrl = profile.avatarUrl {
                                AsyncImage(url: URL(string: avatarUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder(name: profile.name)
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder(name: profile.name)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(profile.name)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(profile.email)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                showingEditProfile = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .sheet(isPresented: $showingEditProfile) {
                    if let profile = authService.userProfile {
                        EditProfileView(profile: profile)
                            .environmentObject(authService)
                    }
                }

                // Statistics Section
                Section {
                    NavigationLink(destination: MyTasksStatsView()) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("任務統計")
                        }
                    }

                    NavigationLink(destination: MyOrganizationsListView()) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("我的組織")
                        }
                    }

                    NavigationLink(destination: MyEventsView()) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("我的活動")
                        }
                    }
                } header: {
                    Text("概覽")
                }

                // Settings Section
                Section {
                    NavigationLink(destination: TimeManagementSettingsView()) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("時間管理")
                        }
                    }

                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("通知設置")
                        }
                    }

                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            Text("外觀")
                        }
                    }
                } header: {
                    Text("設置")
                }

                // About Section
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("關於 Tired")
                        }
                    }

                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("幫助與支持")
                        }
                    }
                } header: {
                    Text("其他")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        do {
                            try authService.signOut()
                        } catch {
                            print("❌ Error signing out: \(error)")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 24)
                            Text("登出")
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }

    private func avatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 70, height: 70)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - My Tasks Stats View

@available(iOS 17.0, *)
struct MyTasksStatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                // 本週統計
                if let stats = viewModel.weeklyStats {
                    Section("本週統計") {
                        HStack {
                            Text("已完成任務")
                            Spacer()
                            Text("\(stats.completedCount)")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("待完成任務")
                            Spacer()
                            Text("\(stats.pendingCount)")
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("總預估時長")
                            Spacer()
                            Text(String(format: "%.1f 小時", stats.totalEstimatedHours))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("完成率")
                            Spacer()
                            HStack(spacing: 4) {
                                Text(String(format: "%.0f%%", stats.completionRate))
                                    .foregroundColor(stats.completionRate >= 70 ? .green : .orange)
                                    .fontWeight(.semibold)

                                ProgressView(value: stats.completionRate / 100)
                                    .frame(width: 60)
                            }
                        }
                    }
                }

                // 分類統計
                if !viewModel.categoryStats.isEmpty {
                    Section("分類統計") {
                        ForEach(viewModel.categoryStats, id: \.category) { stat in
                            HStack {
                                Circle()
                                    .fill(stat.category.color)
                                    .frame(width: 8, height: 8)
                                Text(stat.category.displayName)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(stat.count) 個任務")
                                        .font(.system(size: 14, weight: .medium))
                                    if stat.totalMinutes > 0 {
                                        Text(String(format: "%.1f 小時", stat.totalHours))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section("分類統計") {
                        Text("暫無待辦任務")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("任務統計")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadStats()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - My Organizations List View

@available(iOS 17.0, *)
struct MyOrganizationsListView: View {
    var body: some View {
        Text("我的組織列表")
            .navigationTitle("我的組織")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My Events View

@available(iOS 17.0, *)
struct MyEventsView: View {
    @StateObject private var viewModel = MyEventsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("加載中...")
                    Spacer()
                }
            } else if viewModel.events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("尚未報名任何活動")
                        .font(.system(size: 18, weight: .semibold))
                    Text("前往組織頁面查看並報名活動")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.events) { eventWithReg in
                        EventCard(eventWithReg: eventWithReg)
                    }
                }
                .refreshable {
                    viewModel.loadEvents()
                }
            }
        }
        .navigationTitle("我的活動")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadEvents()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - My Events ViewModel

class MyEventsViewModel: ObservableObject {
    @Published var events: [EventWithRegistration] = []
    @Published var isLoading = false

    private let eventService = EventService()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init() {
        loadEvents()
    }

    func loadEvents() {
        guard let userId = userId else { return }

        isLoading = true

        Task {
            do {
                let events = try await eventService.fetchUserRegisteredEvents(userId: userId)

                await MainActor.run {
                    self.events = events.sorted { $0.event.startAt < $1.event.startAt }
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading events: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Event Card

@available(iOS 17.0, *)
struct EventCard: View {
    let eventWithReg: EventWithRegistration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 組織名稱
            if let org = eventWithReg.organization {
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(org.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // 活動標題
            Text(eventWithReg.event.title)
                .font(.system(size: 16, weight: .semibold))

            // 時間和地點
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(eventWithReg.event.startAt.formatShort())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                if let location = eventWithReg.event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // 報名狀態
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                Text("已報名")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Spacer()

                // 時間狀態
                if eventWithReg.event.startAt < Date() {
                    Text("已結束")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: eventWithReg.event.startAt).day ?? 0
                    if daysUntil == 0 {
                        Text("今天")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    } else if daysUntil > 0 {
                        Text("\(daysUntil) 天後")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Time Management Settings View

@available(iOS 17.0, *)
struct TimeManagementSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var weeklyCapacityHours: Double = 12.0
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每週時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", weeklyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $weeklyCapacityHours, in: 1...40, step: 1)
                }
            } header: {
                Text("時間容量")
            } footer: {
                Text("用於自動排程時計算每週的任務量。建議設置為實際可用的工作/學習時間。")
            }

            Section {
                Button {
                    saveSettings()
                } label: {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("保存中...")
                                .padding(.leading, 8)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("保存設置")
                            Spacer()
                        }
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("時間管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
        .alert("提示", isPresented: $showAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func loadSettings() {
        if let weeklyMinutes = authService.userProfile?.weeklyCapacityMinutes {
            weeklyCapacityHours = Double(weeklyMinutes) / 60.0
        }
    }

    private func saveSettings() {
        isSaving = true

        Task {
            do {
                let weeklyMinutes = Int(weeklyCapacityHours * 60)
                try await authService.updateUserProfile(["weeklyCapacityMinutes": weeklyMinutes])

                await MainActor.run {
                    isSaving = false
                    alertMessage = "設置已保存"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "保存失敗：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Notification Settings View

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @State private var enableNotifications = true
    @State private var taskReminders = true
    @State private var eventReminders = true
    @State private var organizationUpdates = true

    var body: some View {
        Form {
            Section {
                Toggle("啟用通知", isOn: $enableNotifications)
            }

            Section {
                Toggle("任務提醒", isOn: $taskReminders)
                Toggle("活動提醒", isOn: $eventReminders)
                Toggle("組織動態", isOn: $organizationUpdates)
            } header: {
                Text("通知類型")
            }
            .disabled(!enableNotifications)
        }
        .navigationTitle("通知設置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Settings View

@available(iOS 17.0, *)
struct AppearanceSettingsView: View {
    @State private var selectedTheme = "auto"

    var body: some View {
        Form {
            Section {
                Picker("主題", selection: $selectedTheme) {
                    Text("跟隨系統").tag("auto")
                    Text("淺色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("外觀主題")
            }
        }
        .navigationTitle("外觀")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About View

@available(iOS 17.0, *)
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("構建號")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Text("Tired 是一個專為現代斜槓青年設計的多身份任務管理應用。支持學校、工作、社團等多種身份的任務統籌與智能排程。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } header: {
                Text("關於應用")
            }

            Section {
                Link("隱私政策", destination: URL(string: "https://example.com/privacy")!)
                Link("服務條款", destination: URL(string: "https://example.com/terms")!)
                Link("開源許可", destination: URL(string: "https://example.com/licenses")!)
            }
        }
        .navigationTitle("關於 Tired")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help View

@available(iOS 17.0, *)
struct HelpView: View {
    var body: some View {
        List {
            Section("常見問題") {
                NavigationLink("如何創建組織？") {
                    Text("幫助內容")
                }

                NavigationLink("如何使用自動排程？") {
                    Text("幫助內容")
                }

                NavigationLink("如何報名活動？") {
                    Text("幫助內容")
                }
            }

            Section("聯繫我們") {
                Link("發送郵件", destination: URL(string: "mailto:support@tired.app")!)
                Link("反饋問題", destination: URL(string: "https://github.com/tired/issues")!)
            }
        }
        .navigationTitle("幫助與支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}
