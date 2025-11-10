import SwiftUI

// MARK: - Term Settings View
struct TermSettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var viewModel = TermSettingsViewModel()
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

                if viewModel.isLoading {
                    LoadingView(message: "載入學期...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Current Term
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("目前學期")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    if let term = appCoordinator.currentTerm {
                                        HStack {
                                            Image(systemName: "calendar.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(term.displayName)
                                                    .font(.system(size: 20, weight: .bold))

                                                if let start = term.startDate, let end = term.endDate {
                                                    Text("\(DateUtils.formatDisplayDate(start)) - \(DateUtils.formatDisplayDate(end))")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                }
                                            }

                                            Spacer()
                                        }
                                    }
                                }
                            }

                            // All Terms List
                            if !viewModel.allTerms.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("所有學期")
                                        .font(.system(size: 18, weight: .semibold))
                                        .padding(.horizontal)

                                    ForEach(viewModel.allTerms) { term in
                                        TermRow(
                                            term: term,
                                            isCurrent: term.termId == appCoordinator.currentTerm?.termId,
                                            onSelect: {
                                                Task {
                                                    await viewModel.switchToTerm(term, coordinator: appCoordinator)
                                                }
                                            }
                                        )
                                    }
                                }
                            }

                            // Create New Term
                            GlassButton(
                                "建立新學期",
                                icon: "plus.circle.fill",
                                style: .primary
                            ) {
                                viewModel.showCreateTerm = true
                            }
                            .disabled(viewModel.isSwitching)
                        }
                        .padding()
                    }
                }

                if viewModel.isSwitching {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("切換學期中...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("學期管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadTerms()
        }
        .sheet(isPresented: $viewModel.showCreateTerm) {
            CreateTermView()
                .onDisappear {
                    Task {
                        await viewModel.loadTerms()
                    }
                }
        }
    }
}

// MARK: - Term Row
struct TermRow: View {
    let term: TermConfig
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        GlassCard {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(term.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            if isCurrent {
                                GlassBadge(text: "目前", style: .primary)
                            }
                        }

                        if let start = term.startDate, let end = term.endDate {
                            Text("\(DateUtils.formatDisplayDate(start)) - \(DateUtils.formatDisplayDate(end))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !isCurrent {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(isCurrent)
        }
    }
}

// MARK: - Create Term View
struct CreateTermView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTermViewModel()

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
                        // Term ID
                        VStack(alignment: .leading, spacing: 8) {
                            Text("學期代號")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("例如：113-2", text: $viewModel.termId)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Start Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("開始日期")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        // End Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("結束日期")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        // Is Holiday
                        Toggle("假期學期", isOn: $viewModel.isHoliday)
                            .font(.system(size: 16))

                        // Create Button
                        GlassButton(
                            "建立學期",
                            icon: "checkmark.circle.fill",
                            style: .primary
                        ) {
                            Task {
                                await viewModel.createTerm()
                                if viewModel.createSuccess {
                                    ToastManager.shared.showSuccess("學期已建立")
                                    dismiss()
                                }
                            }
                        }
                        .disabled(viewModel.termId.isEmpty || viewModel.isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle("建立新學期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Term Settings View Model
@MainActor
class TermSettingsViewModel: ObservableObject {
    @Published var allTerms: [TermConfig] = []
    @Published var isLoading: Bool = false
    @Published var isSwitching: Bool = false
    @Published var showCreateTerm: Bool = false

    private let termService = TermService.shared

    func loadTerms() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }
        isLoading = true

        do {
            allTerms = try await termService.getAllTerms(userId: userId)
        } catch {
            print("❌ Error loading terms: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func switchToTerm(_ term: TermConfig, coordinator: AppCoordinator) async {
        isSwitching = true

        await coordinator.switchTerm(to: term.termId)
        ToastManager.shared.showSuccess("已切換到 \(term.displayName)")

        isSwitching = false
    }
}

// MARK: - Create Term View Model
@MainActor
class CreateTermViewModel: ObservableObject {
    @Published var termId: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = DateUtils.addDays(Date(), 120)
    @Published var isHoliday: Bool = false
    @Published var isCreating: Bool = false
    @Published var createSuccess: Bool = false

    private let termService = TermService.shared

    func createTerm() async {
        guard let userId = FirebaseService.shared.currentUser?.uid else { return }
        isCreating = true

        let term = TermConfig(
            userId: userId,
            termId: termId,
            startDate: startDate,
            endDate: endDate,
            isHolidayPeriod: isHoliday
        )

        do {
            try await termService.createTerm(term)
            createSuccess = true
        } catch {
            print("❌ Error creating term: \(error.localizedDescription)")
            ToastManager.shared.showError("建立學期失敗")
        }

        isCreating = false
    }
}

// MARK: - Preview
struct TermSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TermSettingsView()
            .environmentObject(AppCoordinator())
    }
}
