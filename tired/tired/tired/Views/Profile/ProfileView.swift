import SwiftUI

@available(iOS 17.0, *)
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileViewModel = ProfileViewModel()
    
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var showingSignOutConfirmation = false
    @State private var isProcessingSignOut = false

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
                                    image.resizable().scaledToFill()
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
                                Text("用戶始於 \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button(action: {
                                showingEditProfile = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppDesignSystem.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .sheet(isPresented: $showingEditProfile) {
                    NavigationView {
                        EditProfileView()
                    }
                }
                
                // --- NEW Statistics Section ---
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            NavigationLink(destination: MyTasksStatsView()) {
                                ProfileStatCard(
                                    value: "\(profileViewModel.totalTasksCompleted)",
                                    label: "完成任務",
                                    icon: "checkmark.circle.fill",
                                    color: .blue
                                )
                            }
                            
                            NavigationLink(destination: MyEventsView()) {
                                ProfileStatCard(
                                    value: "\(profileViewModel.totalEventsAttended)",
                                    label: "參加活動",
                                    icon: "calendar.badge.clock",
                                    color: .orange
                                )
                            }

                            NavigationLink(destination: MyOrganizationsListView()) {
                                // We don't have a direct count, so just make it a link
                                ProfileStatCard(
                                    value: "查看",
                                    label: "我的組織",
                                    icon: "building.2.fill",
                                    color: .purple
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("成就")
                }
                .listRowBackground(Color.clear)


                // Settings Section
                Section {
                    NavigationLink(destination: TimeManagementSettingsView()) {
                        Label("時間管理", systemImage: "clock.fill").foregroundColor(.green)
                    }
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("通知設置", systemImage: "bell.fill").foregroundColor(.red)
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink(destination: RecurringTasksView()) {
                            Label("週期任務管理", systemImage: "repeat.circle.fill").foregroundColor(.blue)
                        }
                    }
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("外觀", systemImage: "paintbrush.fill").foregroundColor(.indigo)
                    }
                } header: {
                    Text("設置")
                }

                // About Section
                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("關於 Tired", systemImage: "info.circle.fill").foregroundColor(.gray)
                    }
                    NavigationLink(destination: HelpView()) {
                        Label("幫助與支持", systemImage: "questionmark.circle.fill").foregroundColor(.cyan)
                    }
                } header: {
                    Text("其他")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(isProcessingSignOut)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .onAppear {
                // 每次進入頁面時刷新數據，確保統計準確
                profileViewModel.fetchStatsAndProfile()
            }
            .confirmationDialog("登出", isPresented: $showingSignOutConfirmation) {
                Button("登出", role: .destructive) {
                    _Concurrency.Task {
                        guard !isProcessingSignOut else { return }
                        await MainActor.run { isProcessingSignOut = true }
                        do {
                            try authService.signOut()
                        } catch {
                            print("❌ Error signing out: \(error)")
                            ToastManager.shared.showToast(message: "登出失敗：\(error.localizedDescription)", type: .error)
                        }
                        await MainActor.run { isProcessingSignOut = false }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if isProcessingSignOut {
                    Text("正在登出，請稍候...")
                } else {
                    Text("您確定要登出嗎？")
                }
            }
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


// --- NEW Stat Card View ---
private struct ProfileStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundColor(color)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 130, height: 130)
        .background(Color.appSecondaryBackground)
        .cornerRadius(20)
    }
}
