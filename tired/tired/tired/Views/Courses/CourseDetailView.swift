import SwiftUI

/// 課程詳情視圖
/// 顯示課程的完整資訊，包含多個功能分頁
@available(iOS 17.0, *)
struct CourseDetailView: View {
    let courseId: String
    
    @StateObject private var viewModel: CourseDetailViewModel
    @EnvironmentObject private var authService: AuthService
    
    @State private var showEditCourse = false
    @State private var showEnrollmentManagement = false
    @State private var showSettings = false
    @State private var showConfirmDrop = false
    @State private var showConfirmArchive = false
    
    init(courseId: String) {
        self.courseId = courseId
        _viewModel = StateObject(wrappedValue: CourseDetailViewModel())
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.course == nil {
                ProgressView("載入中...")
            } else if let course = viewModel.course {
                ScrollView {
                    VStack(spacing: 0) {
                        // 課程頭部
                        courseHeader(course)
                        
                        // Tab 選擇器
                        tabSelector
                        
                        // Tab 內容
                        tabContent(course)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        moreMenu
                    }
                }
            } else {
                errorView
            }
        }
        .sheet(isPresented: $showEnrollmentManagement) {
            if let courseId = viewModel.course?.id {
                EnrollmentManagementView(courseId: courseId)
            }
        }
        .confirmationDialog("確認退選", isPresented: $showConfirmDrop, titleVisibility: .visible) {
            Button("確認退選", role: .destructive) {
                Task {
                    guard let userId = authService.currentUserId else { return }
                    await viewModel.dropCourse(userId: userId)
                }
            }
        } message: {
            Text("確定要退選這門課程嗎？")
        }
        .confirmationDialog("確認封存", isPresented: $showConfirmArchive, titleVisibility: .visible) {
            Button("確認封存", role: .destructive) {
                Task {
                    await viewModel.archiveCourse()
                }
            }
        } message: {
            Text("封存後學生將無法存取課程內容")
        }
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "發生未知錯誤")
        }
        .task {
            if let userId = authService.currentUserId {
                await viewModel.loadCourse(courseId: courseId, userId: userId)
                await viewModel.updateLastAccessed(userId: userId)
            }
        }
        .refreshable {
            if let userId = authService.currentUserId {
                await viewModel.refresh(courseId: courseId, userId: userId)
            }
        }
    }
    
    // MARK: - Course Header
    
    @ViewBuilder
    private func courseHeader(_ course: Course) -> some View {
        VStack(spacing: 0) {
            // 封面圖片或顏色背景
            ZStack {
                if let coverUrl = course.coverImageUrl {
                    AsyncImage(url: URL(string: coverUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(hex: course.color ?? "#3B82F6") ?? .blue)
                    }
                } else {
                    Rectangle().fill(Color(hex: course.color ?? "#3B82F6") ?? .blue)
                }
                
                // 漸層遮罩
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 200)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    // 課程代碼
                    Text(course.code)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    // 課程名稱
                    Text(course.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // 學期 & 學分
                    HStack(spacing: 12) {
                        Label(course.semester, systemImage: "calendar")
                        if let credits = course.credits {
                            Label("\(credits) 學分", systemImage: "graduationcap")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding()
            }
            
            // 資訊卡片
            VStack(spacing: 16) {
                // 角色徽章與狀態
                HStack {
                    if let enrollment = viewModel.currentEnrollment {
                        RoleBadge(role: enrollment.role)
                    }
                    
                    Spacer()
                    
                    // 課程狀態
                    HStack(spacing: 4) {
                        Circle()
                            .fill(course.isActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.statusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 統計資訊（教學人員可見）
                if viewModel.isInstructor, let stats = viewModel.statistics {
                    Divider()
                    
                    HStack(spacing: 20) {
                        StatItem(
                            title: "學生",
                            value: "\(stats.studentCount)",
                            icon: "person.3.fill"
                        )
                        
                        Divider()
                            .frame(height: 30)
                        
                        StatItem(
                            title: "作業",
                            value: "\(stats.totalAssignments)",
                            icon: "doc.text.fill"
                        )
                        
                        Divider()
                            .frame(height: 30)
                        
                        StatItem(
                            title: "公告",
                            value: "\(stats.totalAnnouncements)",
                            icon: "megaphone.fill"
                        )
                    }
                }
                
                // 課程進度條（學生可見）
                if viewModel.isStudent, course.startDate != nil, course.endDate != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("課程進度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", viewModel.courseProgress * 100))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        ProgressView(value: viewModel.courseProgress)
                            .tint(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(availableTabs) { tab in
                    Button(action: {
                        withAnimation {
                            viewModel.selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.body)
                            Text(tab.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.selectedTab == tab ? .accentColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTab == tab ?
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private func tabContent(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch viewModel.selectedTab {
            case .overview:
                overviewContent(course)
            case .announcements:
                announcementsContent
            case .materials:
                materialsContent
            case .assignments:
                assignmentsContent
            case .grades:
                gradesContent
            case .members:
                membersContent
            case .schedule:
                scheduleContent(course)
            }
        }
        .padding()
    }
    
    // MARK: - Overview Tab
    
    @ViewBuilder
    private func overviewContent(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 課程描述
            if let description = course.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("課程描述")
                        .font(.headline)
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // 課程大綱
            if let syllabus = course.syllabus {
                VStack(alignment: .leading, spacing: 8) {
                    Text("課程大綱")
                        .font(.headline)
                    Text(syllabus)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // 課程目標
            if let objectives = course.objectives, !objectives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("課程目標")
                        .font(.headline)
                    ForEach(Array(objectives.enumerated()), id: \.offset) { index, objective in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                            Text(objective)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 選課代碼（教師可見）
            if viewModel.isTeacher, let code = course.enrollmentCode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選課代碼")
                        .font(.headline)
                    
                    HStack {
                        Text(code)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = code
                        }) {
                            Label("複製", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.regenerateEnrollmentCode()
                            }
                        }) {
                            Label("重新生成", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Placeholder Content
    
    private var announcementsContent: some View {
        placeholderContent(icon: "megaphone.fill", message: "公告功能即將推出")
    }
    
    private var materialsContent: some View {
        placeholderContent(icon: "doc.fill", message: "教材功能即將推出")
    }
    
    private var assignmentsContent: some View {
        placeholderContent(icon: "text.book.closed.fill", message: "作業功能即將推出")
    }
    
    private var gradesContent: some View {
        placeholderContent(icon: "chart.bar.fill", message: "成績功能即將推出")
    }
    
    private var membersContent: some View {
        VStack(spacing: 16) {
            if viewModel.isInstructor {
                Button(action: { showEnrollmentManagement = true }) {
                    Label("管理選課名單", systemImage: "person.2.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // 顯示教學人員
            if !viewModel.instructors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("教學人員")
                        .font(.headline)
                    
                    ForEach(viewModel.instructors) { enrollment in
                        memberRow(enrollment: enrollment)
                    }
                }
            }
            
            // 學生數量摘要
            if viewModel.isInstructor {
                HStack {
                    Text("學生人數")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.students.count)")
                        .font(.headline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func scheduleContent(_ course: Course) -> some View {
        if course.schedule.isEmpty {
            placeholderContent(icon: "calendar", message: "尚未設定課表")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(course.schedule) { item in
                    HStack(spacing: 12) {
                        // 星期
                        Text(item.dayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 60, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // 時間
                            Text(item.timeRange)
                                .font(.subheadline)
                            
                            // 地點
                            if let location = item.locationDisplay {
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func memberRow(enrollment: Enrollment) -> some View {
        HStack(spacing: 12) {
            // 頭像佔位
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("教學人員")
                    .font(.subheadline)
                
                Text(enrollment.role.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func placeholderContent(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("無法載入課程")
                .font(.headline)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    // MARK: - More Menu
    
    private var moreMenu: some View {
        Menu {
            if viewModel.isTeacher {
                Button(action: { showEnrollmentManagement = true }) {
                    Label("管理選課", systemImage: "person.2.badge.gearshape")
                }
                
                Button(action: { showConfirmArchive = true }) {
                    Label("封存課程", systemImage: "archivebox")
                }
            }
            
            if viewModel.isStudent {
                Button(role: .destructive, action: { showConfirmDrop = true }) {
                    Label("退選課程", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    // MARK: - Helper
    
    private var availableTabs: [CourseTab] {
        var tabs: [CourseTab] = [.overview, .schedule]
        
        // 所有成員都可以看公告和教材
        if viewModel.isMember {
            tabs.append(contentsOf: [.announcements, .materials])
        }
        
        // 作業和成績
        if viewModel.isMember {
            tabs.append(.assignments)
            if viewModel.isStudent || viewModel.isInstructor {
                tabs.append(.grades)
            }
        }
        
        // 成員管理（教學人員）
        if viewModel.isInstructor {
            tabs.append(.members)
        }
        
        return tabs
    }
}

// MARK: - Helper Views

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(courseId: "preview-course-id")
            .environmentObject(AuthService.shared)
    }
}
