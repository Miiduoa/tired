import Foundation
import SwiftUI
import Combine

/// 課程列表 ViewModel
/// 管理用戶的課程列表，支援按學期分組、篩選和搜索
@MainActor
class CourseListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var enrollmentsWithCourses: [EnrollmentWithCourse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // 篩選與搜索
    @Published var searchText = ""
    @Published var selectedFilter: CourseFilter = .active
    @Published var selectedSemester: String?
    
    // MARK: - Computed Properties
    
    /// 已篩選的課程列表
    var filteredCourses: [EnrollmentWithCourse] {
        var result = enrollmentsWithCourses
        
        // 1. 按狀態篩選
        switch selectedFilter {
        case .active:
            result = result.filter { $0.enrollment.status == .active }
        case .teaching:
            result = result.filter { $0.enrollment.role == .teacher && $0.enrollment.status == .active }
        case .learning:
            result = result.filter { $0.enrollment.role == .student && $0.enrollment.status == .active }
        case .completed:
            result = result.filter { $0.enrollment.status == .completed }
        case .archived:
            result = result.filter { $0.course?.isArchived ?? false }
        case .all:
            break
        }
        
        // 2. 按學期篩選
        if let semester = selectedSemester {
            result = result.filter { $0.course?.semester == semester }
        }
        
        // 3. 按搜索文字篩選
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            result = result.filter { enrollment in
                enrollment.courseName.lowercased().contains(lowercased) ||
                enrollment.courseCode.lowercased().contains(lowercased)
            }
        }
        
        return result
    }
    
    /// 按學期分組的課程
    var coursesBySemester: [String: [EnrollmentWithCourse]] {
        Dictionary(grouping: filteredCourses) { enrollment in
            enrollment.course?.semester ?? "未知學期"
        }
    }
    
    /// 所有學期列表（按時間排序）
    var availableSemesters: [String] {
        let semesters = Set(enrollmentsWithCourses.compactMap { $0.course?.semester })
        return semesters.sorted(by: >)
    }
    
    /// 統計資訊
    var statistics: CourseListStatistics {
        let teaching = enrollmentsWithCourses.filter { 
            $0.enrollment.role == .teacher && $0.enrollment.status == .active 
        }.count
        let learning = enrollmentsWithCourses.filter { 
            $0.enrollment.role == .student && $0.enrollment.status == .active 
        }.count
        let completed = enrollmentsWithCourses.filter { 
            $0.enrollment.status == .completed 
        }.count
        
        return CourseListStatistics(
            totalCourses: enrollmentsWithCourses.count,
            teachingCount: teaching,
            learningCount: learning,
            completedCount: completed
        )
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let courseService = CourseService.shared
    private let enrollmentService = EnrollmentService.shared
    
    // MARK: - Initialization
    
    init() {
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// 載入用戶的課程列表
    func loadCourses(userId: String, includeArchived: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let courses = try await courseService.fetchUserCourses(
                userId: userId,
                includeArchived: includeArchived
            )
            enrollmentsWithCourses = courses
            isLoading = false
        } catch {
            errorMessage = "載入課程失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 重新整理課程列表
    func refresh(userId: String) async {
        await loadCourses(userId: userId, includeArchived: selectedFilter == .archived)
    }
    
    /// 退選課程
    func dropCourse(_ enrollment: EnrollmentWithCourse, userId: String) async {
        guard let courseId = enrollment.course?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await enrollmentService.dropCourse(userId: userId, courseId: courseId)
            // 重新載入列表
            await loadCourses(userId: userId)
        } catch {
            errorMessage = "退選失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 切換課程收藏狀態
    func toggleFavorite(_ enrollment: EnrollmentWithCourse) async {
        guard var updatedEnrollment = enrollmentsWithCourses.first(where: { 
            $0.enrollment.id == enrollment.enrollment.id 
        })?.enrollment else { return }
        
        updatedEnrollment.isFavorite.toggle()
        
        do {
            try await enrollmentService.updateEnrollment(updatedEnrollment)
            // 更新本地狀態
            if let index = enrollmentsWithCourses.firstIndex(where: { 
                $0.enrollment.id == enrollment.enrollment.id 
            }) {
                enrollmentsWithCourses[index] = EnrollmentWithCourse(
                    enrollment: updatedEnrollment,
                    course: enrollment.course
                )
            }
        } catch {
            errorMessage = "更新失敗: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// 封存課程（僅教師可用）
    func archiveCourse(_ enrollment: EnrollmentWithCourse) async {
        guard let courseId = enrollment.course?.id,
              enrollment.enrollment.role == .teacher else { return }
        
        isLoading = true
        
        do {
            try await courseService.archiveCourse(courseId: courseId)
            // 從列表中移除
            enrollmentsWithCourses.removeAll { $0.enrollment.id == enrollment.enrollment.id }
            isLoading = false
        } catch {
            errorMessage = "封存失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // 監聽篩選變更，自動清除學期選擇
        $selectedFilter
            .sink { [weak self] filter in
                if filter != .all {
                    self?.selectedSemester = nil
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - CourseFilter

enum CourseFilter: String, CaseIterable, Identifiable {
    case active = "進行中"
    case teaching = "我教授的"
    case learning = "我學習的"
    case completed = "已完成"
    case archived = "已封存"
    case all = "全部"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .active: return "book.fill"
        case .teaching: return "person.fill.checkmark"
        case .learning: return "graduationcap.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        case .all: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - CourseListStatistics

struct CourseListStatistics {
    let totalCourses: Int
    let teachingCount: Int
    let learningCount: Int
    let completedCount: Int
}
