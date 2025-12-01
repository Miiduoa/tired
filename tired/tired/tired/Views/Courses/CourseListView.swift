import SwiftUI

/// 課程列表視圖
/// 顯示用戶的所有課程，支援篩選、搜索和分組
@available(iOS 17.0, *)
struct CourseListView: View {
    @StateObject private var viewModel = CourseListViewModel()
    @EnvironmentObject private var authService: AuthService
    
    @State private var showCreateCourse = false
    @State private var showEnrollByCourse = false
    @State private var showFilterSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.enrollmentsWithCourses.isEmpty {
                    ProgressView("載入課程中...")
                } else if viewModel.filteredCourses.isEmpty {
                    emptyStateView
                } else {
                    courseListContent
                }
            }
            .navigationTitle("我的課程")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addMenu
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索課程")
            .refreshable {
                await viewModel.refresh(userId: authService.currentUserId ?? "")
            }
            .sheet(isPresented: $showCreateCourse) {
                CreateCourseView()
            }
            .sheet(isPresented: $showEnrollByCourse) {
                EnrollByCourseCodeView()
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .alert("錯誤", isPresented: $viewModel.showError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "發生未知錯誤")
            }
            .task {
                if let userId = authService.currentUserId {
                    await viewModel.loadCourses(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Course List Content
    
    private var courseListContent: some View {
        List {
            // 統計卡片
            statisticsSection
            
            // 按學期分組
            if viewModel.selectedSemester == nil {
                ForEach(viewModel.coursesBySemester.keys.sorted(by: >), id: \.self) { semester in
                    Section(header: Text(semester)) {
                        ForEach(viewModel.coursesBySemester[semester] ?? []) { enrollment in
                            CourseRowView(enrollment: enrollment)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    swipeActions(for: enrollment)
                                }
                        }
                    }
                }
            } else {
                // 選定學期的課程
                ForEach(viewModel.filteredCourses) { enrollment in
                    CourseRowView(enrollment: enrollment)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActions(for: enrollment)
                        }
                }
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        Section {
            HStack(spacing: 20) {
                StatCard(
                    title: "教授",
                    value: viewModel.statistics.teachingCount,
                    icon: "person.fill.checkmark",
                    color: .red
                )
                
                StatCard(
                    title: "學習",
                    value: viewModel.statistics.learningCount,
                    icon: "graduationcap.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "完成",
                    value: viewModel.statistics.completedCount,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("還沒有課程")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("建立新課程或使用選課代碼加入課程")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: { showCreateCourse = true }) {
                    Label("建立課程", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { showEnrollByCourse = true }) {
                    Label("加入課程", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Toolbar Items
    
    private var filterButton: some View {
        Button(action: { showFilterSheet = true }) {
            Label("篩選", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private var addMenu: some View {
        Menu {
            Button(action: { showCreateCourse = true }) {
                Label("建立課程", systemImage: "plus.circle")
            }
            
            Button(action: { showEnrollByCourse = true }) {
                Label("使用代碼加入", systemImage: "number.circle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("狀態篩選") {
                    ForEach(CourseFilter.allCases) { filter in
                        Button(action: {
                            viewModel.selectedFilter = filter
                        }) {
                            HStack {
                                Label(filter.rawValue, systemImage: filter.icon)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                
                if !viewModel.availableSemesters.isEmpty {
                    Section("學期篩選") {
                        Button(action: {
                            viewModel.selectedSemester = nil
                        }) {
                            HStack {
                                Text("全部學期")
                                Spacer()
                                if viewModel.selectedSemester == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        
                        ForEach(viewModel.availableSemesters, id: \.self) { semester in
                            Button(action: {
                                viewModel.selectedSemester = semester
                            }) {
                                HStack {
                                    Text(semester)
                                    Spacer()
                                    if viewModel.selectedSemester == semester {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("篩選課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showFilterSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private func swipeActions(for enrollment: EnrollmentWithCourse) -> some View {
        // 收藏
        Button(action: {
            Task {
                await viewModel.toggleFavorite(enrollment)
            }
        }) {
            Label(
                enrollment.enrollment.isFavorite ? "取消收藏" : "收藏",
                systemImage: enrollment.enrollment.isFavorite ? "star.slash.fill" : "star.fill"
            )
        }
        .tint(.yellow)
        
        // 退選（僅學生）
        if enrollment.enrollment.role == .student {
            Button(role: .destructive, action: {
                Task {
                    guard let userId = authService.currentUserId else { return }
                    await viewModel.dropCourse(enrollment, userId: userId)
                }
            }) {
                Label("退選", systemImage: "xmark.circle.fill")
            }
        }
        
        // 封存（僅教師）
        if enrollment.enrollment.role == .teacher {
            Button(role: .destructive, action: {
                Task {
                    await viewModel.archiveCourse(enrollment)
                }
            }) {
                Label("封存", systemImage: "archivebox.fill")
            }
        }
    }
}

// MARK: - Course Row View

struct CourseRowView: View {
    let enrollment: EnrollmentWithCourse
    
    var body: some View {
        NavigationLink(destination: CourseDetailView(courseId: enrollment.course?.id ?? "")) {
            HStack(spacing: 12) {
                // 課程圖標
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: enrollment.course?.color ?? "#3B82F6") ?? .blue)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 課程名稱
                    Text(enrollment.courseName)
                        .font(.headline)
                    
                    // 課程代碼 & 學期
                    Text("\(enrollment.courseCode) • \(enrollment.semester)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 角色標籤
                    HStack(spacing: 6) {
                        RoleBadge(role: enrollment.enrollment.role)
                        
                        if enrollment.enrollment.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Spacer()
                
                // 狀態指示器
                if let course = enrollment.course {
                    VStack(alignment: .trailing, spacing: 4) {
                        if course.isActive {
                            Text("進行中")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        } else if course.isCompleted {
                            Text("已結束")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let grade = enrollment.enrollment.finalGrade {
                            Text(String(format: "%.0f", grade))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RoleBadge: View {
    let role: CourseRole
    
    var body: some View {
        Text(role.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: role.color) ?? .blue)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Preview

#Preview {
    CourseListView()
        .environmentObject(AuthService.shared)
}
