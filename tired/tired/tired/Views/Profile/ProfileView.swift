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
                        }
                        .padding(.vertical, 8)
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
    @StateObject private var viewModel = TasksStatsViewModel()

    var body: some View {
        List {
            Section("本週統計") {
                HStack {
                    Text("已完成任務")
                    Spacer()
                    Text("\(viewModel.completedCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("待完成任務")
                    Spacer()
                    Text("\(viewModel.pendingCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("總預估時長")
                    Spacer()
                    Text(viewModel.formattedEstimatedTime)
                        .foregroundColor(.secondary)
                }
            }

            Section("分類統計") {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("學校")
                    Spacer()
                    Text("\(viewModel.schoolCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("工作")
                    Spacer()
                    Text("\(viewModel.workCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                    Text("社團")
                    Spacer()
                    Text("\(viewModel.clubCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("生活")
                    Spacer()
                    Text("\(viewModel.personalCount)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("任務統計")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tasks Stats ViewModel

import FirebaseAuth
import Combine

class TasksStatsViewModel: ObservableObject {
    @Published var completedCount = 0
    @Published var pendingCount = 0
    @Published var totalEstimatedMinutes = 0
    @Published var schoolCount = 0
    @Published var workCount = 0
    @Published var clubCount = 0
    @Published var personalCount = 0

    private var cancellables = Set<AnyCancellable>()
    private let db = FirebaseManager.shared.db

    var formattedEstimatedTime: String {
        let hours = totalEstimatedMinutes / 60
        let minutes = totalEstimatedMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours) 小時 \(minutes) 分鐘"
        } else if hours > 0 {
            return "\(hours) 小時"
        } else {
            return "\(minutes) 分鐘"
        }
    }

    init() {
        loadStats()
    }

    private func loadStats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Get start of current week
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        // Listen to user's tasks
        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }

                let tasks = documents.compactMap { try? $0.data(as: Task.self) }

                // Filter tasks for this week
                let weekTasks = tasks.filter { task in
                    if let plannedDate = task.plannedDate {
                        return plannedDate >= startOfWeek
                    }
                    if let deadline = task.deadlineAt {
                        return deadline >= startOfWeek
                    }
                    return !task.isDone
                }

                // Calculate stats
                self.completedCount = weekTasks.filter { $0.isDone }.count
                self.pendingCount = weekTasks.filter { !$0.isDone }.count
                self.totalEstimatedMinutes = weekTasks.filter { !$0.isDone }.compactMap { $0.estimatedMinutes }.reduce(0, +)

                // Category stats (all pending tasks)
                let pendingTasks = tasks.filter { !$0.isDone }
                self.schoolCount = pendingTasks.filter { $0.category == .school }.count
                self.workCount = pendingTasks.filter { $0.category == .work }.count
                self.clubCount = pendingTasks.filter { $0.category == .club }.count
                self.personalCount = pendingTasks.filter { $0.category == .personal }.count
            }
    }
}

// MARK: - My Organizations List View

@available(iOS 17.0, *)
struct MyOrganizationsListView: View {
    @StateObject private var viewModel = OrganizationsViewModel()

    var body: some View {
        List {
            if viewModel.myMemberships.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("還沒有加入任何組織")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("前往「組織」頁面探索並加入組織")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.myMemberships) { membershipWithOrg in
                    if let org = membershipWithOrg.organization {
                        NavigationLink(destination: OrganizationDetailView(organization: org)) {
                            HStack(spacing: 12) {
                                // Avatar
                                if let avatarUrl = org.avatarUrl {
                                    AsyncImage(url: URL(string: avatarUrl)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        orgAvatarPlaceholder(name: org.name)
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    orgAvatarPlaceholder(name: org.name)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(org.name)
                                            .font(.system(size: 15, weight: .medium))
                                        if org.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 12))
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        Text(membershipWithOrg.membership.role.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)

                                        Text(org.type.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的組織")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func orgAvatarPlaceholder(name: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - My Events View

@available(iOS 17.0, *)
struct MyEventsView: View {
    @StateObject private var viewModel = MyEventsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("還沒有報名任何活動")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("前往組織頁面查看並報名活動")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                // Upcoming events
                let upcomingEvents = viewModel.events.filter { $0.event.startAt > Date() }
                if !upcomingEvents.isEmpty {
                    Section("即將到來") {
                        ForEach(upcomingEvents) { eventWithReg in
                            MyEventRow(eventWithReg: eventWithReg)
                        }
                    }
                }

                // Past events
                let pastEvents = viewModel.events.filter { $0.event.startAt <= Date() }
                if !pastEvents.isEmpty {
                    Section("已結束") {
                        ForEach(pastEvents) { eventWithReg in
                            MyEventRow(eventWithReg: eventWithReg)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的活動")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadEvents()
        }
    }
}

// MARK: - My Event Row

@available(iOS 17.0, *)
struct MyEventRow: View {
    let eventWithReg: EventWithRegistration

    var isUpcoming: Bool {
        eventWithReg.event.startAt > Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(eventWithReg.event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isUpcoming ? .primary : .secondary)

                Spacer()

                if isUpcoming {
                    Text("即將開始")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label(eventWithReg.event.startAt.formatLong(), systemImage: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if let location = eventWithReg.event.location {
                    Label(location, systemImage: "mappin")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if let orgName = eventWithReg.organization?.name {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.system(size: 10))
                    Text(orgName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - My Events ViewModel

class MyEventsViewModel: ObservableObject {
    @Published var events: [EventWithRegistration] = []
    @Published var isLoading = true

    private let eventService = EventService()

    init() {
        _Concurrency.Task {
            await loadEvents()
        }
    }

    func loadEvents() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoading = false }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            let events = try await eventService.fetchUserRegisteredEvents(userId: userId)
            await MainActor.run {
                self.events = events.sorted { $0.event.startAt > $1.event.startAt }
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading events: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Time Management Settings View

@available(iOS 17.0, *)
struct TimeManagementSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var weeklyCapacityHours: Double = 12.0
    @State private var dailyCapacityHours: Double = 8.0
    @State private var isSaving = false
    @State private var showingSaved = false

    private let userService = UserService()

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
                        .onChange(of: weeklyCapacityHours) { _, _ in
                            saveSettings()
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日時間容量")
                        Spacer()
                        Text("\(String(format: "%.0f", dailyCapacityHours)) 小時")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $dailyCapacityHours, in: 1...16, step: 1)
                        .onChange(of: dailyCapacityHours) { _, _ in
                            saveSettings()
                        }
                }
            } header: {
                Text("時間容量")
            } footer: {
                HStack {
                    Text("用於自動排程時計算每週和每日的任務量")
                    Spacer()
                    if showingSaved {
                        Text("已儲存")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("時間管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            weeklyCapacityHours = Double(profile.weeklyCapacityMinutes ?? 720) / 60.0
            dailyCapacityHours = Double(profile.dailyCapacityMinutes ?? 480) / 60.0
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        isSaving = true
        _Concurrency.Task {
            do {
                try await userService.updateTimeManagementSettings(
                    userId: userId,
                    weeklyCapacityMinutes: Int(weeklyCapacityHours * 60),
                    dailyCapacityMinutes: Int(dailyCapacityHours * 60)
                )
                await MainActor.run {
                    showingSaved = true
                    isSaving = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving time settings: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Notification Settings View

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var enableNotifications = true
    @State private var taskReminders = true
    @State private var eventReminders = true
    @State private var organizationUpdates = true
    @State private var showingSaved = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Toggle("啟用通知", isOn: $enableNotifications)
                    .onChange(of: enableNotifications) { _, _ in saveSettings() }
            }

            Section {
                Toggle("任務提醒", isOn: $taskReminders)
                    .onChange(of: taskReminders) { _, _ in saveSettings() }
                Toggle("活動提醒", isOn: $eventReminders)
                    .onChange(of: eventReminders) { _, _ in saveSettings() }
                Toggle("組織動態", isOn: $organizationUpdates)
                    .onChange(of: organizationUpdates) { _, _ in saveSettings() }
            } header: {
                Text("通知類型")
            } footer: {
                if showingSaved {
                    Text("已儲存")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .disabled(!enableNotifications)
        }
        .navigationTitle("通知設置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            enableNotifications = profile.notificationsEnabled ?? true
            taskReminders = profile.taskReminders ?? true
            eventReminders = profile.eventReminders ?? true
            organizationUpdates = profile.organizationUpdates ?? true
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        _Concurrency.Task {
            do {
                try await userService.updateNotificationSettings(
                    userId: userId,
                    notificationsEnabled: enableNotifications,
                    taskReminders: taskReminders,
                    eventReminders: eventReminders,
                    organizationUpdates: organizationUpdates
                )
                await MainActor.run {
                    showingSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving notification settings: \(error)")
            }
        }
    }
}

// MARK: - Appearance Settings View

@available(iOS 17.0, *)
struct AppearanceSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTheme = "auto"
    @State private var showingSaved = false

    private let userService = UserService()

    var body: some View {
        Form {
            Section {
                Picker("主題", selection: $selectedTheme) {
                    Text("跟隨系統").tag("auto")
                    Text("淺色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
                .onChange(of: selectedTheme) { _, _ in
                    saveSettings()
                }
            } header: {
                Text("外觀主題")
            } footer: {
                if showingSaved {
                    Text("已儲存")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("外觀")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let profile = authService.userProfile {
            selectedTheme = profile.theme ?? "auto"
        }
    }

    private func saveSettings() {
        guard let userId = authService.userProfile?.id else { return }

        _Concurrency.Task {
            do {
                try await userService.updateAppearanceSettings(userId: userId, theme: selectedTheme)
                await MainActor.run {
                    showingSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaved = false
                    }
                }
            } catch {
                print("❌ Error saving appearance settings: \(error)")
            }
        }
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
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("構建號")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
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

            Section("主要功能") {
                FeatureRow(icon: "checkmark.circle.fill", color: .green, title: "任務管理", description: "創建、排程和追蹤多身份任務")
                FeatureRow(icon: "calendar.badge.clock", color: .orange, title: "智能排程", description: "自動分配任務到合適的時間段")
                FeatureRow(icon: "building.2.fill", color: .purple, title: "組織管理", description: "加入組織，接收任務和活動通知")
                FeatureRow(icon: "person.2.fill", color: .blue, title: "活動報名", description: "查看和報名組織舉辦的活動")
            }

            Section("法律條款") {
                NavigationLink {
                    LegalDocumentView(title: "隱私政策", content: privacyPolicyContent)
                } label: {
                    Label("隱私政策", systemImage: "hand.raised.fill")
                }

                NavigationLink {
                    LegalDocumentView(title: "服務條款", content: termsOfServiceContent)
                } label: {
                    Label("服務條款", systemImage: "doc.text.fill")
                }

                NavigationLink {
                    LegalDocumentView(title: "開源許可", content: openSourceLicensesContent)
                } label: {
                    Label("開源許可", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Section {
                Text("© 2024 Tired App. All rights reserved.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("關於 Tired")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyPolicyContent: String {
        """
        隱私政策

        最後更新日期：2024年1月

        1. 資訊收集
        我們收集以下類型的資訊：
        • 帳戶資訊：您的電子郵件地址和顯示名稱
        • 任務資料：您創建的任務、排程和完成狀態
        • 組織資訊：您加入的組織和會員身份
        • 使用數據：應用程式的使用情況和偏好設定

        2. 資訊使用
        我們使用收集的資訊來：
        • 提供和維護我們的服務
        • 改善用戶體驗
        • 發送服務相關通知

        3. 資訊保護
        我們採用業界標準的安全措施來保護您的個人資訊。

        4. 聯繫我們
        如有任何問題，請發送郵件至 support@tired.app
        """
    }

    private var termsOfServiceContent: String {
        """
        服務條款

        最後更新日期：2024年1月

        1. 接受條款
        使用 Tired 應用程式即表示您同意這些服務條款。

        2. 服務描述
        Tired 是一個任務管理和排程應用程式，幫助用戶管理多種身份下的任務和活動。

        3. 用戶責任
        • 您負責維護帳戶安全
        • 您同意不濫用服務
        • 您對上傳的內容負責

        4. 隱私
        您的隱私對我們很重要。請參閱我們的隱私政策了解詳情。

        5. 服務變更
        我們保留隨時修改或終止服務的權利。

        6. 免責聲明
        服務按「現狀」提供，不做任何形式的保證。
        """
    }

    private var openSourceLicensesContent: String {
        """
        開源許可

        Tired 使用了以下開源軟體：

        Firebase iOS SDK
        Apache License 2.0
        https://github.com/firebase/firebase-ios-sdk

        Google Sign-In for iOS
        Apache License 2.0
        https://github.com/google/GoogleSignIn-iOS

        Swift
        Apache License 2.0
        https://github.com/apple/swift

        感謝所有開源貢獻者的付出！
        """
    }
}

// MARK: - Feature Row

@available(iOS 17.0, *)
struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Legal Document View

@available(iOS 17.0, *)
struct LegalDocumentView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14))
                .padding()
        }
        .navigationTitle(title)
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
                    HelpDetailView(
                        title: "如何創建組織？",
                        content: """
                        創建組織步驟：

                        1. 前往「組織」頁面
                        2. 點擊右上角的「+」按鈕
                        3. 填寫組織名稱和類型
                        4. 選擇組織類型（學校、公司、社團等）
                        5. 添加組織描述（選填）
                        6. 點擊「創建」按鈕

                        創建後，您將自動成為該組織的擁有者，可以：
                        • 邀請其他成員加入
                        • 管理成員角色
                        • 發布組織動態
                        • 創建活動和任務
                        • 啟用小應用（任務看板、活動報名等）
                        """
                    )
                }

                NavigationLink("如何使用自動排程？") {
                    HelpDetailView(
                        title: "如何使用自動排程？",
                        content: """
                        自動排程功能說明：

                        什麼是自動排程？
                        自動排程（AutoPlan）會智能地將您的待辦任務分配到合適的日期。

                        使用步驟：
                        1. 前往「任務」頁面
                        2. 確保有待排程的任務（Backlog中的任務）
                        3. 點擊工具列中的「自動排程」按鈕
                        4. 系統會根據以下因素自動分配：
                           • 任務的截止日期
                           • 任務的優先級
                           • 每日時間容量設定
                           • 已鎖定日期的任務

                        提示：
                        • 在「設定 > 時間管理」中調整每日/每週容量
                        • 為重要任務設定截止日期以獲得更好的排程效果
                        • 使用「鎖定日期」功能防止特定任務被重新排程
                        """
                    )
                }

                NavigationLink("如何報名活動？") {
                    HelpDetailView(
                        title: "如何報名活動？",
                        content: """
                        活動報名步驟：

                        1. 前往您已加入的組織頁面
                        2. 切換到「小應用」標籤
                        3. 點擊「活動報名」應用
                        4. 瀏覽可用的活動列表
                        5. 點擊想要參加的活動的「立即報名」按鈕

                        報名成功後：
                        • 活動會顯示「已報名」標記
                        • 系統會自動在您的任務中創建活動提醒
                        • 您可以在「我的 > 我的活動」查看所有報名的活動

                        取消報名：
                        • 在活動詳情頁點擊「取消報名」按鈕
                        • 相關的任務提醒也會自動刪除
                        """
                    )
                }

                NavigationLink("如何同步組織任務？") {
                    HelpDetailView(
                        title: "如何同步組織任務？",
                        content: """
                        同步組織任務步驟：

                        1. 前往組織頁面，點擊「小應用」標籤
                        2. 進入「任務看板」應用
                        3. 瀏覽組織發布的任務
                        4. 點擊任務旁的「同步到個人」按鈕

                        同步後的任務：
                        • 會出現在您的任務中樞
                        • 可以設定個人的計劃日期
                        • 可以標記完成狀態
                        • 保留與組織任務的關聯

                        注意事項：
                        • 組織管理員可以查看任務完成情況
                        • 同步的任務會標記來源組織
                        """
                    )
                }
            }

            Section("使用技巧") {
                NavigationLink("任務分類說明") {
                    HelpDetailView(
                        title: "任務分類說明",
                        content: """
                        Tired 支援四種任務分類：

                        🔵 學校
                        適用於：課程作業、考試準備、報告撰寫等學業相關任務

                        🔴 工作
                        適用於：專案任務、會議準備、工作報告等職場相關任務

                        🟣 社團
                        適用於：社團活動、志工服務、課外活動等社團相關任務

                        🟢 生活
                        適用於：個人事務、生活瑣事、休閒活動等個人生活任務

                        選擇正確的分類可以幫助您：
                        • 更好地統計各領域的時間分配
                        • 按分類篩選和查看任務
                        • 了解自己在不同身份上的投入
                        """
                    )
                }

                NavigationLink("優先級使用建議") {
                    HelpDetailView(
                        title: "優先級使用建議",
                        content: """
                        任務優先級說明：

                        🔴 高優先級
                        • 緊急且重要的任務
                        • 有嚴格截止日期的任務
                        • 會影響其他工作的前置任務

                        🟡 中優先級
                        • 重要但不緊急的任務
                        • 有彈性截止日期的任務
                        • 常規工作任務

                        🟢 低優先級
                        • 可以延後處理的任務
                        • 沒有明確截止日期的任務
                        • 日常瑣事

                        建議：
                        • 避免所有任務都設為高優先級
                        • 定期檢視和調整優先級
                        • 優先完成高優先級任務
                        """
                    )
                }
            }

            Section("聯繫我們") {
                Button {
                    if let url = URL(string: "mailto:support@tired.app") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("發送郵件", systemImage: "envelope.fill")
                }

                Button {
                    if let url = URL(string: "https://github.com/Miiduoa/tired/issues") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("反饋問題", systemImage: "exclamationmark.bubble.fill")
                }
            }
        }
        .navigationTitle("幫助與支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Detail View

@available(iOS 17.0, *)
struct HelpDetailView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14))
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
