import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class ActivityBoardModernViewModel: ObservableObject {
    @Published private(set) var events: [Event] = []
    @Published private(set) var polls: [Poll] = []
    @Published private(set) var isLoading = false
    @Published var selectedTab: ActivityTab = .events
    
    private let membership: TenantMembership
    
    enum ActivityTab: String, CaseIterable {
        case events = "活動"
        case polls = "投票"
    }
    
    init(membership: TenantMembership) {
        self.membership = membership
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let eventsTask = ActivitiesAPI.getEvents(tenantId: membership.tenant.id)
            async let pollsTask = fetchPolls()
            
            events = try await eventsTask
            polls = try await pollsTask
        } catch {
            print("⚠️ Failed to load activities: \(error)")
        }
    }
    
    func registerForEvent(_ event: Event, userId: String?) async {
        guard let userId else { return }
        
        do {
            try await ActivitiesAPI.rsvpForEvent(eventId: event.id, userId: userId)
            HapticFeedback.success()
            ToastCenter.shared.show("報名成功！", style: .success)
            await load()
        } catch {
            HapticFeedback.error()
            ToastCenter.shared.show("報名失敗，請稍後再試", style: .error)
        }
    }
    
    func submitVote(poll: Poll, selectedOptions: [String], userId: String?) async {
        guard let userId else { return }
        
        do {
            try await ActivitiesAPI.submitVote(pollId: poll.id, userId: userId, selectedOptions: selectedOptions)
            HapticFeedback.success()
            ToastCenter.shared.show("投票成功！", style: .success)
            await load()
        } catch {
            HapticFeedback.error()
            ToastCenter.shared.show("投票失敗", style: .error)
        }
    }
    
    private func fetchPolls() async throws -> [Poll] {
        // Mock data for now
        return [
            Poll(
                id: "poll1",
                tenantId: membership.tenant.id,
                question: "下個月團隊活動選擇？",
                options: ["登山健行", "密室逃脫", "美食聚會", "運動競賽"],
                allowMultiple: false,
                deadline: Date().addingTimeInterval(604800),
                totalVotes: 45,
                userVoted: false
            ),
            Poll(
                id: "poll2",
                tenantId: membership.tenant.id,
                question: "辦公室改善建議（可多選）",
                options: ["增加綠植", "改善照明", "升級咖啡機", "添置按摩椅"],
                allowMultiple: true,
                deadline: Date().addingTimeInterval(259200),
                totalVotes: 32,
                userVoted: true
            )
        ]
    }
}

// MARK: - Main View

struct ActivityBoardView_Modern: View {
    let membership: TenantMembership
    @StateObject private var viewModel: ActivityBoardModernViewModel
    @State private var showCreateEvent = false
    @State private var showCreatePoll = false
    @EnvironmentObject private var authService: AuthService
    
    init(membership: TenantMembership) {
        self.membership = membership
        _viewModel = StateObject(wrappedValue: ActivityBoardModernViewModel(membership: membership))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientMeshBackground()
                
                VStack(spacing: 0) {
                    // 自訂 Segment Control
                    customSegmentControl
                        .padding(.horizontal, TTokens.spacingLG)
                        .padding(.top, TTokens.spacingSM)
                    
                    // 內容區
                    TabView(selection: $viewModel.selectedTab) {
                        eventsView
                            .tag(ActivityBoardModernViewModel.ActivityTab.events)
                        
                        pollsView
                            .tag(ActivityBoardModernViewModel.ActivityTab.polls)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("活動中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
    
    // MARK: - Segment Control
    
    private var customSegmentControl: some View {
        HStack(spacing: 0) {
            ForEach(ActivityBoardModernViewModel.ActivityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedTab = tab
                    }
                    HapticFeedback.selection()
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.selectedTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TTokens.spacingSM)
                        .background {
                            if viewModel.selectedTab == tab {
                                Capsule()
                                    .fill(TTokens.gradientPrimary)
                                    .matchedGeometryEffect(id: "tab", in: tabNamespace)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
    
    @Namespace private var tabNamespace
    
    // MARK: - Events View
    
    private var eventsView: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.events.isEmpty {
                VStack(spacing: TTokens.spacingLG) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard(height: 180)
                    }
                }
                .padding(TTokens.spacingLG)
            } else if viewModel.events.isEmpty {
                AppEmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "暫無活動",
                    subtitle: "新的活動會顯示在這裡"
                )
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: TTokens.spacingLG) {
                    ForEach(Array(viewModel.events.enumerated()), id: \.element.id) { index, event in
                        EventCard(event: event) {
                            await viewModel.registerForEvent(event, userId: authService.currentUser?.id)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: viewModel.events.count)
                    }
                }
                .padding(TTokens.spacingLG)
            }
        }
    }
    
    // MARK: - Polls View
    
    private var pollsView: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.polls.isEmpty {
                VStack(spacing: TTokens.spacingLG) {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonCard(height: 200)
                    }
                }
                .padding(TTokens.spacingLG)
            } else if viewModel.polls.isEmpty {
                AppEmptyStateView(
                    systemImage: "chart.bar.doc.horizontal",
                    title: "暫無投票",
                    subtitle: "新的投票會顯示在這裡"
                )
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: TTokens.spacingLG) {
                    ForEach(Array(viewModel.polls.enumerated()), id: \.element.id) { index, poll in
                        PollCard(poll: poll) { poll, options in
                            await viewModel.submitVote(poll: poll, selectedOptions: options, userId: authService.currentUser?.id)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: viewModel.polls.count)
                    }
                }
                .padding(TTokens.spacingLG)
            }
        }
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Menu {
            Button("新增活動", systemImage: "calendar.badge.plus") {
                showCreateEvent = true
            }
            Button("新增投票", systemImage: "chart.bar.doc.horizontal") {
                showCreatePoll = true
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(TTokens.gradientPrimary)
        }
    }
}

// MARK: - Event Card

private struct EventCard: View {
    let event: Event
    let onRegister: () async -> Void
    @State private var isRegistering = false
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                // 標題與狀態
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                        Text(event.title)
                            .font(.title3.weight(.bold))
                        
                        if let location = event.location {
                            Label(location, systemImage: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if event.requiresRSVP {
                        TagBadge(text: "需報名", color: .creative)
                    }
                }
                
                // 描述
                if let description = event.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Divider()
                
                // 時間與按鈕
                HStack {
                    VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                        Label(event.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "clock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.tint)
                        
                        if event.registeredCount > 0 {
                            Text("\(event.registeredCount) 人已報名")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if event.requiresRSVP {
                        Button {
                            isRegistering = true
                            Task {
                                await onRegister()
                                isRegistering = false
                            }
                        } label: {
                            Group {
                                if isRegistering {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("報名")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(width: 80, height: 36)
                        }
                        .buttonStyle(FluidButtonStyle())
                        .disabled(isRegistering)
                    }
                }
            }
        }
    }
}

// MARK: - Poll Card

private struct PollCard: View {
    let poll: Poll
    let onSubmit: (_ poll: Poll, _ selectedOptions: [String]) async -> Void
    @State private var selectedOptions: Set<String> = []
    @State private var showResults = false
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: TTokens.spacingMD) {
                // 問題標題
                HStack(alignment: .top) {
                    Text(poll.question)
                        .font(.headline.weight(.bold))
                    
                    Spacer()
                    
                    if poll.userVoted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.success)
                    }
                }
                
                // 選項列表
                if poll.userVoted || showResults {
                    // 顯示結果
                    VStack(spacing: TTokens.spacingSM) {
                        ForEach(poll.options, id: \.self) { option in
                            pollResultBar(option: option)
                        }
                    }
                } else {
                    // 顯示投票選項
                    VStack(spacing: TTokens.spacingSM) {
                        ForEach(poll.options, id: \.self) { option in
                            pollOptionButton(option: option)
                        }
                    }
                }
                
                Divider()
                
                // 底部信息
                HStack {
                    VStack(alignment: .leading, spacing: TTokens.spacingXS) {
                        Text("\(poll.totalVotes) 人投票")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Label(poll.deadline.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !poll.userVoted {
                        if showResults {
                            Button("返回投票") {
                                withAnimation { showResults = false }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tint)
                        } else {
                            HStack(spacing: TTokens.spacingSM) {
                                Button("查看結果") {
                                    withAnimation { showResults = true }
                                    HapticFeedback.selection()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                
                                Button("提交") {
                                    Task {
                                        await onSubmit(poll, Array(selectedOptions))
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 70, height: 32)
                                .buttonStyle(FluidButtonStyle())
                                .disabled(selectedOptions.isEmpty)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func pollOptionButton(option: String) -> some View {
        Button {
            HapticFeedback.selection()
            if poll.allowMultiple {
                if selectedOptions.contains(option) {
                    selectedOptions.remove(option)
                } else {
                    selectedOptions.insert(option)
                }
            } else {
                selectedOptions = [option]
            }
        } label: {
            HStack {
                Image(systemName: selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedOptions.contains(option) ? Color.tint : .secondary)
                
                Text(option)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, TTokens.spacingMD)
            .padding(.vertical, TTokens.spacingSM)
            .background {
                RoundedRectangle(cornerRadius: TTokens.radiusMD)
                    .fill(selectedOptions.contains(option) ? Color.tint.opacity(0.1) : Color.secondary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: TTokens.radiusMD)
                            .strokeBorder(
                                selectedOptions.contains(option) ? Color.tint.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func pollResultBar(option: String) -> some View {
        let percentage = Double.random(in: 0.2...0.9) // Mock percentage
        
        return VStack(alignment: .leading, spacing: TTokens.spacingXS) {
            HStack {
                Text(option)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.0f%%", percentage * 100))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tint)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TTokens.gradientPrimary)
                        .frame(width: geo.size.width * percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Data Models

struct Event: Codable, Identifiable {
    let id: String
    let tenantId: String
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let location: String?
    let requiresRSVP: Bool
    let capacity: Int?
    let registeredCount: Int
}

struct Poll: Codable, Identifiable {
    let id: String
    let tenantId: String
    let question: String
    let options: [String]
    let allowMultiple: Bool
    let deadline: Date
    let totalVotes: Int
    let userVoted: Bool
}
