import SwiftUI

// MARK: - Me View
struct MeView: View {
    @StateObject private var viewModel = MeViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        ProfileHeaderCard(
                            profile: appCoordinator.userProfile,
                            term: appCoordinator.currentTerm
                        )

                        // Stats
                        StatsCard(
                            streak: appCoordinator.userProfile?.streakDays ?? 0,
                            totalCompleted: appCoordinator.userProfile?.totalCompletedTasks ?? 0,
                            termCompleted: viewModel.termCompletedCount
                        )

                        // Settings Sections
                        GlassCard {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "calendar",
                                    title: "學期管理",
                                    action: { viewModel.showTermSettings = true }
                                )

                                Divider()
                                    .padding(.leading, 52)

                                SettingsRow(
                                    icon: "gauge",
                                    title: "容量設定",
                                    action: { viewModel.showCapacitySettings = true }
                                )

                                Divider()
                                    .padding(.leading, 52)

                                SettingsRow(
                                    icon: "square.and.arrow.up",
                                    title: "匯出本學期經歷",
                                    action: { Task { await viewModel.exportExperience() } }
                                )
                            }
                        }

                        // Logout Button
                        GlassButton("登出", icon: "rectangle.portrait.and.arrow.right", style: .destructive) {
                            try? FirebaseService.shared.signOut()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("我")
        }
        .task {
            await viewModel.loadStats()
        }
        .sheet(isPresented: $viewModel.showTermSettings) {
            Text("Term Settings")
        }
        .sheet(isPresented: $viewModel.showCapacitySettings) {
            Text("Capacity Settings")
        }
        .alert("匯出經歷", isPresented: $viewModel.showExportSheet) {
            Button("複製到剪貼簿") {
                if let text = viewModel.exportedText {
                    UIPasteboard.general.string = text
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(viewModel.exportedText ?? "準備中...")
        }
    }
}

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let profile: UserProfile?
    let term: TermConfig?

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Circle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    )

                VStack(spacing: 4) {
                    Text(FirebaseService.shared.currentUser?.displayName ?? "用戶")
                        .font(.system(size: 20, weight: .bold))

                    if let term = term {
                        Text(term.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    let streak: Int
    let totalCompleted: Int
    let termCompleted: Int

    var body: some View {
        GlassCard {
            HStack(spacing: 0) {
                StatItem(
                    value: "\(streak)",
                    label: "連續天數",
                    icon: "flame.fill",
                    color: .orange
                )

                Divider()
                    .frame(height: 60)

                StatItem(
                    value: "\(termCompleted)",
                    label: "本學期完成",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                Divider()
                    .frame(height: 60)

                StatItem(
                    value: "\(totalCompleted)",
                    label: "總完成",
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
    }
}

struct StatItem: View {
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
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
