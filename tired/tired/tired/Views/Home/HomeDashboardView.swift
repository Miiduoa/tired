import SwiftUI
import FirebaseAuth

@available(iOS 17.0, *)
struct HomeDashboardView: View {
    @StateObject private var tasksViewModel = TasksViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddTask = false
    @State private var showingAutoplan = false
    @State private var isAutoplanRunning = false
    @State private var selectedPost: PostWithAuthor? // 用於顯示貼文詳情
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Header: 情感化問候
                        headerSection
                        
                        // 2. Hero Section: 當前焦點（最重要的一件事）
                        if let firstTask = tasksViewModel.todayTasks.first {
                            NavigationLink(destination: TaskDetailView(viewModel: tasksViewModel, task: firstTask)) {
                                FocusTaskCard(task: firstTask)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            EmptyStateCard()
                        }
                        
                        // 3. Stats: 今日概況（小部件）
                        HStack(spacing: 16) {
                            Button {
                                NotificationCenter.default.post(name: .navigateToTasksTab, object: nil)
                            } label: {
                                HomeStatCard(
                                    icon: "checklist",
                                    value: "\(tasksViewModel.todayTasks.count)",
                                    label: "今日剩餘",
                                    color: .blue
                                )
                            }
                            .buttonStyle(ScaleButtonStyle()) // 加入按壓效果

                            Button {
                                NotificationCenter.default.post(name: .navigateToTasksTab, object: nil)
                            } label: {
                                HomeStatCard(
                                    icon: "calendar",
                                    value: "\(tasksViewModel.weekTasks.count)",
                                    label: "本週待辦",
                                    color: .orange
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        
                        // 4. Critical Updates: 只顯示重要公告 (不顯示一般廢文)
                        if !feedViewModel.posts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("最新動態")
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    NavigationLink(destination: FeedView()) {
                                        Text("查看全部")
                                            .font(.caption)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(feedViewModel.posts.prefix(3), id: \.post.id) { postWithAuthor in
                                    Button {
                                        selectedPost = postWithAuthor
                                    } label: {
                                        SimplePostRow(post: postWithAuthor)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }

                        quickActionsSection
                        todayPreviewSection
                    }
                    .padding()
                    .padding(.bottom, 80) // TabBar 空間
                }
            }
            .onAppear {
                // 重新整理數據
                tasksViewModel.setupSubscriptions()
                feedViewModel.refresh()
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: tasksViewModel)
            }
            .sheet(isPresented: $showingAutoplan) {
                AutoPlanView(viewModel: tasksViewModel)
            }
            // 顯示貼文詳情/評論
            .sheet(item: $selectedPost) { post in
                CommentsView(postWithAuthor: post, feedViewModel: feedViewModel)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                
                Text(authService.currentUser?.displayName ?? "使用者")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            
            // 搜尋按鈕 (替代原本的搜尋 Tab)
            NavigationLink(destination: GlobalSearchView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary)
                    .padding(10)
                    .background(Color.appSecondaryBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 20)
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早安，準備好了嗎？"
        case 12..<18: return "午後，保持專注。"
        default: return "辛苦了，記得休息。"
        }
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            Button {
                showingAddTask = true
            } label: {
                Label("新增任務", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppDesignSystem.accentGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            
            Button {
                showingAutoplan = true
            } label: {
                Label("智能排程", systemImage: "wand.and.stars")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppDesignSystem.glassOverlay, lineWidth: 1)
                    )
                    .foregroundColor(.primary)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var todayPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日任務摘要")
                    .font(.headline)
                Spacer()
                if tasksViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }
            
            let todayTasks = tasksViewModel.todayTasks.prefix(3)
            if todayTasks.isEmpty {
                Text("目前沒有排定的任務，試著安排一個吧。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(12)
            } else {
                ForEach(todayTasks, id: \.id) { task in
                    NavigationLink(destination: TaskDetailView(viewModel: tasksViewModel, task: task)) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.forCategory(task.category))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(2)
                                if let deadline = task.deadlineAt {
                                    Text(deadline, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if task.isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if task.isOverdue {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color.appSecondaryBackground)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func runAutoplan() {
        guard !isAutoplanRunning else { return }
        isAutoplanRunning = true
        _Concurrency.Task {
            await MainActor.run {
                tasksViewModel.runAutoplan()
            }
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { isAutoplanRunning = false }
        }
    }
}

// 簡化的卡片組件
@available(iOS 17.0, *)
struct FocusTaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("現在焦點")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appAccent.opacity(0.2))
                    .foregroundStyle(Color.appAccent)
                    .cornerRadius(8)
                Spacer()
                if let deadline = task.deadlineAt {
                    Text(deadline.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            
            Text(task.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
            
            if let desc = task.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

@available(iOS 17.0, *)
struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.green.opacity(0.8))
            Text("太棒了，目前沒有急事")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text("去喝杯咖啡吧 ☕️")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
}

@available(iOS 17.0, *)
struct HomeStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}

struct SimplePostRow: View {
    let post: PostWithAuthor
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: post.author?.avatarUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.author?.name ?? "未知用戶")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                Text(post.post.contentText)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }
}
