import Foundation
import SwiftUI
import Combine

/// 課程詳情 ViewModel
/// 管理單一課程的詳細資訊、成員列表、權限檢查
@MainActor
class CourseDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var course: Course?
    @Published var currentEnrollment: Enrollment?
    @Published var enrollments: [Enrollment] = []
    @Published var statistics: CourseStatistics?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Tab 選擇
    @Published var selectedTab: CourseTab = .overview
    
    // MARK: - Computed Properties
    
    /// 是否為課程成員
    var isMember: Bool {
        currentEnrollment?.status == .active
    }
    
    /// 是否為教師
    var isTeacher: Bool {
        currentEnrollment?.role == .teacher && currentEnrollment?.status == .active
    }
    
    /// 是否為助教
    var isTA: Bool {
        currentEnrollment?.role == .ta && currentEnrollment?.status == .active
    }
    
    /// 是否為學生
    var isStudent: Bool {
        currentEnrollment?.role == .student && currentEnrollment?.status == .active
    }
    
    /// 是否為教學人員（教師或助教）
    var isInstructor: Bool {
        isTeacher || isTA
    }
    
    /// 權限檢查
    var canManageContent: Bool {
        currentEnrollment?.role.hasPermission(.manageContent) ?? false
    }
    
    var canManageEnrollment: Bool {
        currentEnrollment?.role.hasPermission(.manageEnrollment) ?? false
    }
    
    var canGrade: Bool {
        currentEnrollment?.role.hasPermission(.grade) ?? false
    }
    
    var canEditSettings: Bool {
        currentEnrollment?.role.hasPermission(.editSettings) ?? false
    }
    
    var canTakeAttendance: Bool {
        currentEnrollment?.role.hasPermission(.takeAttendance) ?? false
    }
    
    /// 學生列表
    var students: [Enrollment] {
        enrollments.filter { $0.role == .student && $0.status == .active }
    }
    
    /// 教學人員列表
    var instructors: [Enrollment] {
        enrollments.filter { 
            ($0.role == .teacher || $0.role == .ta) && $0.status == .active 
        }
    }
    
    /// 課程狀態描述
    var statusDescription: String {
        course?.statusDescription ?? "未知"
    }
    
    /// 課程進度（基於時間）
    var courseProgress: Double {
        guard let course = course,
              let start = course.startDate,
              let end = course.endDate else {
            return 0.0
        }
        
        let now = Date()
        guard now >= start else { return 0.0 }
        guard now <= end else { return 1.0 }
        
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        
        return elapsed / total
    }
    
    // MARK: - Private Properties
    
    private let courseService = CourseService.shared
    private let enrollmentService = EnrollmentService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// 載入課程詳情
    func loadCourse(courseId: String, userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. 載入課程資訊
            let fetchedCourse = try await courseService.fetchCourse(id: courseId)
            course = fetchedCourse
            
            // 2. 載入當前用戶的選課記錄
            let enrollment = try await enrollmentService.fetchEnrollment(
                userId: userId,
                courseId: courseId
            )
            currentEnrollment = enrollment
            
            // 3. 如果是教學人員，載入所有選課記錄
            if enrollment?.isInstructor ?? false {
                let allEnrollments = try await enrollmentService.fetchCourseEnrollments(
                    courseId: courseId
                )
                enrollments = allEnrollments
            }
            
            // 4. 載入統計資料
            if enrollment?.isInstructor ?? false {
                let stats = try await courseService.fetchCourseStatistics(courseId: courseId)
                statistics = stats
            }
            
            isLoading = false
        } catch {
            errorMessage = "載入課程失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 重新整理課程資訊
    func refresh(courseId: String, userId: String) async {
        await loadCourse(courseId: courseId, userId: userId)
    }
    
    /// 更新課程資訊
    func updateCourse(_ updatedCourse: Course) async {
        isLoading = true
        
        do {
            try await courseService.updateCourse(updatedCourse)
            course = updatedCourse
            isLoading = false
        } catch {
            errorMessage = "更新課程失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 重新生成選課代碼
    func regenerateEnrollmentCode() async {
        guard let courseId = course?.id, isTeacher else { return }
        
        isLoading = true
        
        do {
            let newCode = try await courseService.regenerateEnrollmentCode(courseId: courseId)
            course?.enrollmentCode = newCode
            isLoading = false
        } catch {
            errorMessage = "重新生成代碼失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 移除學生
    func removeStudent(enrollment: Enrollment) async {
        guard let enrollmentId = enrollment.id,
              canManageEnrollment else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.deleteEnrollment(enrollmentId: enrollmentId)
            // 從列表中移除
            enrollments.removeAll { $0.id == enrollmentId }
            // 更新統計
            if let courseId = course?.id {
                statistics = try await courseService.fetchCourseStatistics(courseId: courseId)
            }
            isLoading = false
        } catch {
            errorMessage = "移除學生失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 變更學生角色
    func changeStudentRole(enrollment: Enrollment, newRole: CourseRole) async {
        guard let enrollmentId = enrollment.id,
              canManageEnrollment else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.updateEnrollmentRole(
                enrollmentId: enrollmentId,
                newRole: newRole
            )
            // 更新本地狀態
            if let index = enrollments.firstIndex(where: { $0.id == enrollmentId }) {
                enrollments[index].role = newRole
            }
            isLoading = false
        } catch {
            errorMessage = "變更角色失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 封存課程
    func archiveCourse() async {
        guard let courseId = course?.id, isTeacher else { return }
        
        isLoading = true
        
        do {
            try await courseService.archiveCourse(courseId: courseId)
            course?.isArchived = true
            isLoading = false
        } catch {
            errorMessage = "封存課程失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 退選課程
    func dropCourse(userId: String) async {
        guard let courseId = course?.id, isStudent else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.dropCourse(userId: userId, courseId: courseId)
            currentEnrollment?.status = .dropped
            isLoading = false
        } catch {
            errorMessage = "退選失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 更新最後存取時間
    func updateLastAccessed(userId: String) async {
        guard let courseId = course?.id else { return }
        
        try? await enrollmentService.updateLastAccessedAt(
            userId: userId,
            courseId: courseId
        )
    }
}

// MARK: - CourseTab

enum CourseTab: String, CaseIterable, Identifiable {
    case overview = "簡介"
    case announcements = "公告"
    case materials = "教材"
    case assignments = "作業"
    case grades = "成績"
    case members = "成員"
    case schedule = "課表"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "info.circle.fill"
        case .announcements: return "megaphone.fill"
        case .materials: return "doc.fill"
        case .assignments: return "text.book.closed.fill"
        case .grades: return "chart.bar.fill"
        case .members: return "person.3.fill"
        case .schedule: return "calendar"
        }
    }
}
