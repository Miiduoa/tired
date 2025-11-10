import SwiftUI
import UserNotifications
import Combine

// MARK: - ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var pushEnabled = false
    @Published var emailEnabled = true
    @Published var smsEnabled = false
    
    @Published var selectedTheme: AppTheme = .system
    @Published var selectedLanguage: AppLanguage = .zhHant
    
    @Published var analyticsEnabled = true
    @Published var crashReportsEnabled = true
    
    private let notificationService = NotificationService.shared
    
    enum AppTheme: String, CaseIterable {
        case system = "跟隨系統"
        case light = "淺色"
        case dark = "深色"
    }
    
    enum AppLanguage: String, CaseIterable {
        case zhHant = "繁體中文"
        case zhHans = "简体中文"
        case en = "English"
    }
    
    func loadSettings() {
        // 檢查通知權限
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationsEnabled = settings.authorizationStatus == .authorized
                pushEnabled = settings.authorizationStatus == .authorized
            }
        }
        
        // 從 UserDefaults 加載設置
        selectedTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "app_theme") ?? "system") ?? .system
        selectedLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "zhHant") ?? .zhHant
        analyticsEnabled = UserDefaults.standard.bool(forKey: "analytics_enabled")
        crashReportsEnabled = UserDefaults.standard.bool(forKey: "crash_reports_enabled")
    }
    
    func requestNotificationPermission() {
        notificationService.requestAuthorization()
        
        // 重新檢查狀態
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            loadSettings()
        }
    }
    
    func saveTheme(_ theme: AppTheme) {
        selectedTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
        applyTheme(theme)
    }
    
    func saveLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        // TODO: Apply language change
        ToastCenter.shared.show("語言設置將在重啟後生效", style: .info)
    }
    
    func toggleAnalytics(_ enabled: Bool) {
        analyticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analytics_enabled")
    }
    
    func toggleCrashReports(_ enabled: Bool) {
        crashReportsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "crash_reports_enabled")
    }
    
    private func applyTheme(_ theme: AppTheme) {
        // TODO: Apply theme immediately
        HapticFeedback.success()
        ToastCenter.shared.show("主題已更新", style: .success)
    }
    
    func clearCache() async {
        // Mock cache clearing
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        HapticFeedback.success()
        ToastCenter.shared.show("緩存已清除", style: .success)
    }
    
    func logout() {
        // TODO: Implement logout
        HapticFeedback.success()
        ToastCenter.shared.show("已登出", style: .info)
    }
}

// MARK: - Main View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showLogoutConfirmation = false
    @State private var showClearCacheConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientMeshBackground()
                
                List {
                    // 通知設置
                    notificationSection
                    
                    // 外觀設置
                    appearanceSection
                    
                    // 隱私設置
                    privacySection
                    
                    // 關於
                    aboutSection
                    
                    // 登出
                    logoutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadSettings()
            }
            .confirmationDialog("確定要登出嗎？", isPresented: $showLogoutConfirmation) {
                Button("登出", role: .destructive) {
                    viewModel.logout()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("確定要清除緩存嗎？", isPresented: $showClearCacheConfirmation) {
                Button("清除", role: .destructive) {
                    Task { await viewModel.clearCache() }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Notification Section
    
    private var notificationSection: some View {
        Section {
            // 推播通知總開關
            Button {
                if !viewModel.notificationsEnabled {
                    viewModel.requestNotificationPermission()
                } else {
                    // 引導用戶到設置
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.tint)
                    Text("推播通知")
                    Spacer()
                    Image(systemName: viewModel.notificationsEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(viewModel.notificationsEnabled ? Color.success : Color.danger)
                }
            }
            
            // 通知類型
            if viewModel.notificationsEnabled {
                Toggle(isOn: $viewModel.pushEnabled) {
                    Label("推播", systemImage: "app.badge")
                }
                
                Toggle(isOn: $viewModel.emailEnabled) {
                    Label("電子郵件", systemImage: "envelope")
                }
                
                Toggle(isOn: $viewModel.smsEnabled) {
                    Label("簡訊", systemImage: "message")
                }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("管理您接收通知的方式")
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            // 主題選擇
            NavigationLink {
                themeSelectionView
            } label: {
                HStack {
                    Label("主題", systemImage: "paintbrush")
                    Spacer()
                    Text(viewModel.selectedTheme.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 語言選擇
            NavigationLink {
                languageSelectionView
            } label: {
                HStack {
                    Label("語言", systemImage: "globe")
                    Spacer()
                    Text(viewModel.selectedLanguage.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("外觀")
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section {
            Toggle(isOn: $viewModel.analyticsEnabled) {
                Label("數據分析", systemImage: "chart.bar")
            }
            .onChange(of: viewModel.analyticsEnabled) { _, newValue in
                viewModel.toggleAnalytics(newValue)
            }
            
            Toggle(isOn: $viewModel.crashReportsEnabled) {
                Label("崩潰報告", systemImage: "exclamationmark.triangle")
            }
            .onChange(of: viewModel.crashReportsEnabled) { _, newValue in
                viewModel.toggleCrashReports(newValue)
            }
            
            NavigationLink {
                privacyPolicyView
            } label: {
                Label("隱私政策", systemImage: "hand.raised")
            }
            
            NavigationLink {
                termsOfServiceView
            } label: {
                Label("服務條款", systemImage: "doc.text")
            }
        } header: {
            Text("隱私與安全")
        } footer: {
            Text("幫助我們改善應用體驗")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0 (Build 1)")
                    .foregroundStyle(.secondary)
            }
            
            Button {
                showClearCacheConfirmation = true
            } label: {
                Label("清除緩存", systemImage: "trash")
                    .foregroundStyle(Color.danger)
            }
            
            NavigationLink {
                feedbackView
            } label: {
                Label("意見反饋", systemImage: "envelope.badge")
            }
            
            NavigationLink {
                aboutView
            } label: {
                Label("關於 Tired", systemImage: "info.circle")
            }
        } header: {
            Text("關於")
        }
    }
    
    // MARK: - Logout Section
    
    private var logoutSection: some View {
        Section {
            Button {
                showLogoutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.danger)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Theme Selection View
    
    private var themeSelectionView: some View {
        List {
            ForEach(SettingsViewModel.AppTheme.allCases, id: \.self) { theme in
                Button {
                    viewModel.saveTheme(theme)
                    HapticFeedback.selection()
                } label: {
                    HStack {
                        Text(theme.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("選擇主題")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Language Selection View
    
    private var languageSelectionView: some View {
        List {
            ForEach(SettingsViewModel.AppLanguage.allCases, id: \.self) { language in
                Button {
                    viewModel.saveLanguage(language)
                    HapticFeedback.selection()
                } label: {
                    HStack {
                        Text(language.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("選擇語言")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Privacy Policy View
    
    private var privacyPolicyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                Text("隱私政策")
                    .font(.title.weight(.bold))
                
                Text("我們重視您的隱私並致力於保護您的個人信息...")
                    .font(.body)
                
                Text("信息收集")
                    .font(.headline.weight(.semibold))
                    .padding(.top, TTokens.spacingMD)
                
                Text("我們可能收集以下類型的信息：\n• 帳戶信息\n• 使用數據\n• 設備信息")
                    .font(.body)
                
                Text("信息使用")
                    .font(.headline.weight(.semibold))
                    .padding(.top, TTokens.spacingMD)
                
                Text("我們使用收集的信息來：\n• 提供和改善服務\n• 個性化用戶體驗\n• 發送通知和更新")
                    .font(.body)
                
                Text("更新日期：2025年1月1日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, TTokens.spacingLG)
            }
            .padding(TTokens.spacingLG)
        }
        .navigationTitle("隱私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Terms of Service View
    
    private var termsOfServiceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                Text("服務條款")
                    .font(.title.weight(.bold))
                
                Text("歡迎使用 Tired。使用本服務即表示您同意以下條款...")
                    .font(.body)
                
                Text("接受條款")
                    .font(.headline.weight(.semibold))
                    .padding(.top, TTokens.spacingMD)
                
                Text("使用本服務，您同意受本協議的約束。")
                    .font(.body)
                
                Text("服務描述")
                    .font(.headline.weight(.semibold))
                    .padding(.top, TTokens.spacingMD)
                
                Text("Tired 提供企業和校園管理工具...")
                    .font(.body)
                
                Text("更新日期：2025年1月1日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, TTokens.spacingLG)
            }
            .padding(TTokens.spacingLG)
        }
        .navigationTitle("服務條款")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Feedback View
    
    private var feedbackView: some View {
        FeedbackForm()
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        ScrollView {
            VStack(spacing: TTokens.spacingXL) {
                // Logo
                Image(systemName: "app.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(TTokens.gradientPrimary)
                    .padding(.top, TTokens.spacingXL)
                
                VStack(spacing: TTokens.spacingSM) {
                    Text("Tired")
                        .font(.largeTitle.weight(.bold))
                    Text("企業與校園管理平台")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                GlassmorphicCard(tint: .tint) {
                    VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                        infoRow(title: "版本", value: "1.0.0")
                        Divider()
                        infoRow(title: "Build", value: "1")
                        Divider()
                        infoRow(title: "開發者", value: "Tired Team")
                    }
                }
                .padding(.horizontal, TTokens.spacingLG)
                
                VStack(spacing: TTokens.spacingMD) {
                    Text("© 2025 Tired. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: TTokens.spacingLG) {
                        Link(destination: URL(string: "https://tired.com")!) {
                            Label("網站", systemImage: "globe")
                                .font(.caption)
                        }
                        
                        Link(destination: URL(string: "mailto:support@tired.com")!) {
                            Label("支援", systemImage: "envelope")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.bottom, TTokens.spacingXL)
        }
        .navigationTitle("關於")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Feedback Form

struct FeedbackForm: View {
    @State private var feedbackType: FeedbackType = .bug
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss
    
    enum FeedbackType: String, CaseIterable {
        case bug = "錯誤回報"
        case feature = "功能建議"
        case other = "其他"
    }
    
    var body: some View {
        Form {
            Section("類型") {
                Picker("反饋類型", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("內容") {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
            }
            
            Section {
                Button {
                    submitFeedback()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("提交")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(feedbackText.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("意見反饋")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isSubmitting = false
                HapticFeedback.success()
                ToastCenter.shared.show("感謝您的反饋！", style: .success)
                dismiss()
            }
        }
    }
}
