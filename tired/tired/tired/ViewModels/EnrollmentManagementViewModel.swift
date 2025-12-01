import Foundation
import SwiftUI
import Combine

/// 選課管理 ViewModel
/// 用於管理課程的選課名單、審核申請、變更角色
@MainActor
class EnrollmentManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var enrollmentsWithUsers: [EnrollmentWithUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // 篩選
    @Published var selectedRoleFilter: CourseRole?
    @Published var selectedStatusFilter: EnrollmentStatus?
    @Published var searchText = ""
    
    // MARK: - Computed Properties
    
    /// 已篩選的選課列表
    var filteredEnrollments: [EnrollmentWithUser] {
        var result = enrollmentsWithUsers
        
        // 按角色篩選
        if let role = selectedRoleFilter {
            result = result.filter { $0.enrollment.role == role }
        }
        
        // 按狀態篩選
        if let status = selectedStatusFilter {
            result = result.filter { $0.enrollment.status == status }
        }
        
        // 按搜索文字篩選
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            result = result.filter { enrollment in
                enrollment.displayName.lowercased().contains(lowercased) ||
                (enrollment.email?.lowercased().contains(lowercased) ?? false)
            }
        }
        
        return result
    }
    
    /// 按角色分組
    var enrollmentsByRole: [CourseRole: [EnrollmentWithUser]] {
        Dictionary(grouping: filteredEnrollments) { $0.enrollment.role }
    }
    
    /// 統計資訊
    var statistics: EnrollmentStatistics {
        let teachers = enrollmentsWithUsers.filter { $0.enrollment.role == .teacher && $0.enrollment.status == .active }.count
        let tas = enrollmentsWithUsers.filter { $0.enrollment.role == .ta && $0.enrollment.status == .active }.count
        let students = enrollmentsWithUsers.filter { $0.enrollment.role == .student && $0.enrollment.status == .active }.count
        let observers = enrollmentsWithUsers.filter { $0.enrollment.role == .observer && $0.enrollment.status == .active }.count
        
        let active = enrollmentsWithUsers.filter { $0.enrollment.status == .active }.count
        let pending = enrollmentsWithUsers.filter { $0.enrollment.status == .pending }.count
        let dropped = enrollmentsWithUsers.filter { $0.enrollment.status == .dropped }.count
        
        return EnrollmentStatistics(
            totalEnrollments: enrollmentsWithUsers.count,
            teacherCount: teachers,
            taCount: tas,
            studentCount: students,
            observerCount: observers,
            activeCount: active,
            pendingCount: pending,
            droppedCount: dropped
        )
    }
    
    // MARK: - Private Properties
    
    private let enrollmentService = EnrollmentService.shared
    private let userService = UserService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// 載入課程的選課列表
    func loadEnrollments(courseId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. 獲取所有選課記錄
            let enrollments = try await enrollmentService.fetchCourseEnrollments(courseId: courseId)
            
            // 2. 批次獲取用戶資料
            var enrollmentsWithUserData: [EnrollmentWithUser] = []
            for enrollment in enrollments {
                let user = try? await userService.getUserProfile(userId: enrollment.userId)
                enrollmentsWithUserData.append(
                    EnrollmentWithUser(enrollment: enrollment, user: user)
                )
            }
            
            enrollmentsWithUsers = enrollmentsWithUserData
            isLoading = false
        } catch {
            errorMessage = "載入選課名單失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 重新整理選課列表
    func refresh(courseId: String) async {
        await loadEnrollments(courseId: courseId)
    }
    
    /// 移除成員
    func removeMember(_ enrollmentWithUser: EnrollmentWithUser) async {
        guard let enrollmentId = enrollmentWithUser.enrollment.id else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.deleteEnrollment(enrollmentId: enrollmentId)
            // 從列表中移除
            enrollmentsWithUsers.removeAll { $0.enrollment.id == enrollmentId }
            isLoading = false
        } catch {
            errorMessage = "移除成員失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 變更成員角色
    func changeMemberRole(_ enrollmentWithUser: EnrollmentWithUser, newRole: CourseRole) async {
        guard let enrollmentId = enrollmentWithUser.enrollment.id else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.updateEnrollmentRole(
                enrollmentId: enrollmentId,
                newRole: newRole
            )
            
            // 更新本地狀態
            if let index = enrollmentsWithUsers.firstIndex(where: { $0.enrollment.id == enrollmentId }) {
                var updatedEnrollment = enrollmentsWithUsers[index].enrollment
                updatedEnrollment.role = newRole
                enrollmentsWithUsers[index] = EnrollmentWithUser(
                    enrollment: updatedEnrollment,
                    user: enrollmentsWithUsers[index].user
                )
            }
            
            isLoading = false
        } catch {
            errorMessage = "變更角色失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 批准選課申請
    func approveEnrollment(_ enrollmentWithUser: EnrollmentWithUser) async {
        guard let enrollmentId = enrollmentWithUser.enrollment.id else { return }
        
        isLoading = true
        
        do {
            try await enrollmentService.updateEnrollmentStatus(
                enrollmentId: enrollmentId,
                newStatus: .active
            )
            
            // 更新本地狀態
            if let index = enrollmentsWithUsers.firstIndex(where: { $0.enrollment.id == enrollmentId }) {
                var updatedEnrollment = enrollmentsWithUsers[index].enrollment
                updatedEnrollment.status = .active
                enrollmentsWithUsers[index] = EnrollmentWithUser(
                    enrollment: updatedEnrollment,
                    user: enrollmentsWithUsers[index].user
                )
            }
            
            isLoading = false
        } catch {
            errorMessage = "批准失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 拒絕選課申請
    func rejectEnrollment(_ enrollmentWithUser: EnrollmentWithUser) async {
        guard let enrollmentId = enrollmentWithUser.enrollment.id else { return }
        
        isLoading = true
        
        do {
            // 直接刪除選課記錄
            try await enrollmentService.deleteEnrollment(enrollmentId: enrollmentId)
            enrollmentsWithUsers.removeAll { $0.enrollment.id == enrollmentId }
            isLoading = false
        } catch {
            errorMessage = "拒絕失敗: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// 批次匯入學生（通過 email 列表）
    func importStudents(courseId: String, emails: [String]) async -> ImportResult {
        var successCount = 0
        var failedEmails: [String] = []
        
        for email in emails {
            do {
                // 1. 通過 email 查找用戶
                if let user = try? await userService.getUserByEmail(email) {
                    // 2. 創建選課記錄
                    let enrollment = Enrollment(
                        userId: user.id ?? "",
                        courseId: courseId,
                        role: .student,
                        status: .active,
                        enrollmentMethod: .imported
                    )
                    try await enrollmentService.createEnrollment(enrollment)
                    successCount += 1
                } else {
                    failedEmails.append(email)
                }
            } catch {
                failedEmails.append(email)
            }
        }
        
        // 重新載入列表
        await loadEnrollments(courseId: courseId)
        
        return ImportResult(
            totalCount: emails.count,
            successCount: successCount,
            failedEmails: failedEmails
        )
    }
    
    /// 匯出學生名單（CSV 格式）
    func exportStudentsCSV() -> String {
        var csv = "姓名,Email,角色,狀態,選課時間\n"
        
        for enrollmentWithUser in filteredEnrollments {
            let name = enrollmentWithUser.displayName
            let email = enrollmentWithUser.email ?? "N/A"
            let role = enrollmentWithUser.enrollment.role.displayName
            let status = enrollmentWithUser.enrollment.status.displayName
            let date = formatDate(enrollmentWithUser.enrollment.enrolledAt)
            
            csv += "\(name),\(email),\(role),\(status),\(date)\n"
        }
        
        return csv
    }
    
    // MARK: - Private Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - EnrollmentStatistics

struct EnrollmentStatistics {
    let totalEnrollments: Int
    let teacherCount: Int
    let taCount: Int
    let studentCount: Int
    let observerCount: Int
    let activeCount: Int
    let pendingCount: Int
    let droppedCount: Int
}

// MARK: - ImportResult

struct ImportResult {
    let totalCount: Int
    let successCount: Int
    let failedEmails: [String]
    
    var failedCount: Int {
        failedEmails.count
    }
    
    var successRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(successCount) / Double(totalCount)
    }
}
