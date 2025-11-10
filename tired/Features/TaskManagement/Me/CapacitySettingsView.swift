import SwiftUI

// MARK: - Capacity Settings View
struct CapacitySettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel = CapacitySettingsViewModel()
    @Environment(\.dismiss) private var dismiss

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
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "gauge.high")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("容量設定")
                                .font(.system(size: 28, weight: .bold))

                            Text("設定你每天可以專注學習的分鐘數")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Weekday Capacity
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)

                                    Text("平日容量（週一至週五）")
                                        .font(.system(size: 16, weight: .semibold))

                                    Spacer()
                                }

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("\(viewModel.weekdayCapacity) 分鐘")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.blue)

                                        Spacer()

                                        Text("≈ \(viewModel.weekdayCapacity / 60) 小時 \(viewModel.weekdayCapacity % 60) 分")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { Double(viewModel.weekdayCapacity) },
                                            set: { viewModel.weekdayCapacity = Int($0) }
                                        ),
                                        in: 30...480,
                                        step: 15
                                    )
                                    .tint(.blue)

                                    HStack {
                                        Text("30 分")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text("8 小時")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // Weekend Capacity
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "moon.stars")
                                        .font(.system(size: 24))
                                        .foregroundColor(.purple)

                                    Text("週末容量（週六至週日）")
                                        .font(.system(size: 16, weight: .semibold))

                                    Spacer()
                                }

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("\(viewModel.weekendCapacity) 分鐘")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.purple)

                                        Spacer()

                                        Text("≈ \(viewModel.weekendCapacity / 60) 小時 \(viewModel.weekendCapacity % 60) 分")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { Double(viewModel.weekendCapacity) },
                                            set: { viewModel.weekendCapacity = Int($0) }
                                        ),
                                        in: 30...480,
                                        step: 15
                                    )
                                    .tint(.purple)

                                    HStack {
                                        Text("30 分")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text("8 小時")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // Recommendations
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                    Text("建議")
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    RecommendationRow(
                                        icon: "graduationcap.fill",
                                        text: "大學生：平日 180-240 分鐘，週末 120-180 分鐘"
                                    )

                                    RecommendationRow(
                                        icon: "briefcase.fill",
                                        text: "工作者：平日 120-180 分鐘，週末 60-120 分鐘"
                                    )

                                    RecommendationRow(
                                        icon: "person.fill",
                                        text: "個人發展：依個人時間彈性調整"
                                    )
                                }
                            }
                        }

                        // Save Button
                        GlassButton(
                            "儲存設定",
                            icon: "checkmark.circle.fill",
                            style: .primary
                        ) {
                            Task {
                                await viewModel.saveCapacity(coordinator: appCoordinator)
                                dismiss()
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                    .padding()
                }

                if viewModel.isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("儲存中...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("容量設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadCurrentCapacity(coordinator: appCoordinator)
        }
    }
}

// MARK: - Recommendation Row
struct RecommendationRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Capacity Settings View Model
@MainActor
class CapacitySettingsViewModel: ObservableObject {
    @Published var weekdayCapacity: Int = 180
    @Published var weekendCapacity: Int = 120
    @Published var isSaving: Bool = false

    func loadCurrentCapacity(coordinator: AppCoordinator) async {
        if let profile = coordinator.userProfile {
            weekdayCapacity = profile.weekdayCapacityMin
            weekendCapacity = profile.weekendCapacityMin
        }
    }

    func saveCapacity(coordinator: AppCoordinator) async {
        isSaving = true

        await coordinator.updateCapacity(weekday: weekdayCapacity, weekend: weekendCapacity)
        ToastManager.shared.showSuccess("容量設定已更新")

        isSaving = false
    }
}

// MARK: - Preview
struct CapacitySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CapacitySettingsView()
            .environmentObject(AppCoordinator())
    }
}
