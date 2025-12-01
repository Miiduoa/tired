import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Enrollment (課程註冊/選課記錄)

/// 代表用戶與課程的關係
/// 取代原有的 Membership 在課程場景中的使用
struct Enrollment: Codable, Identifiable, Hashable {
    @DocumentID var id: String?

    // MARK: - 關聯
    var userId: String              // 使用者 ID
    var courseId: String            // 課程 ID

    // MARK: - 角色
    var role: CourseRole            // 課程中的角色（教師、學生、助教等）

    // MARK: - 狀態
    var status: EnrollmentStatus    // 選課狀態（活躍、退選、完成等）
    var enrollmentMethod: EnrollmentMethod  // 選課方式

    // MARK: - 成績與出席
    var finalGrade: Double?         // 最終成績 (0-100)
    var letterGrade: String?        // 等第 (A+, A, B+, etc.)
    var attendanceRate: Double?     // 出席率 (0-1)
    var totalAbsences: Int          // 缺席次數

    // MARK: - 學習進度
    var completedAssignments: Int   // 已完成作業數
    var totalAssignments: Int       // 總作業數
    var submittedOnTime: Int        // 準時繳交次數
    var lateSubmissions: Int        // 遲交次數

    // MARK: - 個人化設定
    var nickname: String?           // 暱稱（在課程中的顯示名稱）
    var notes: String?              // 個人筆記
    var isFavorite: Bool            // 是否加入我的最愛
    var notificationsEnabled: Bool  // 是否啟用通知

    // MARK: - 時間戳記
    var enrolledAt: Date            // 選課時間
    var lastAccessedAt: Date?       // 最後存取時間
    var completedAt: Date?          // 完成時間（課程結束）
    var droppedAt: Date?            // 退選時間
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, courseId
        case role, status, enrollmentMethod
        case finalGrade, letterGrade, attendanceRate, totalAbsences
        case completedAssignments, totalAssignments, submittedOnTime, lateSubmissions
        case nickname, notes, isFavorite, notificationsEnabled
        case enrolledAt, lastAccessedAt, completedAt, droppedAt, updatedAt
    }

    init(
        id: String? = nil,
        userId: String,
        courseId: String,
        role: CourseRole,
        status: EnrollmentStatus = .active,
        enrollmentMethod: EnrollmentMethod = .selfEnroll,
        finalGrade: Double? = nil,
        letterGrade: String? = nil,
        attendanceRate: Double? = nil,
        totalAbsences: Int = 0,
        completedAssignments: Int = 0,
        totalAssignments: Int = 0,
        submittedOnTime: Int = 0,
        lateSubmissions: Int = 0,
        nickname: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        notificationsEnabled: Bool = true,
        enrolledAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        completedAt: Date? = nil,
        droppedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.courseId = courseId
        self.role = role
        self.status = status
        self.enrollmentMethod = enrollmentMethod
        self.finalGrade = finalGrade
        self.letterGrade = letterGrade
        self.attendanceRate = attendanceRate
        self.totalAbsences = totalAbsences
        self.completedAssignments = completedAssignments
        self.totalAssignments = totalAssignments
        self.submittedOnTime = submittedOnTime
        self.lateSubmissions = lateSubmissions
        self.nickname = nickname
        self.notes = notes
        self.isFavorite = isFavorite
        self.notificationsEnabled = notificationsEnabled
        self.enrolledAt = enrolledAt
        self.lastAccessedAt = lastAccessedAt
        self.completedAt = completedAt
        self.droppedAt = droppedAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Enrollment Extensions

extension Enrollment {
    /// 作業完成率
    var assignmentCompletionRate: Double {
        guard totalAssignments > 0 else { return 0.0 }
        return Double(completedAssignments) / Double(totalAssignments)
    }

    /// 準時繳交率
    var onTimeSubmissionRate: Double {
        guard completedAssignments > 0 else { return 0.0 }
        return Double(submittedOnTime) / Double(completedAssignments)
    }

    /// 是否為教學人員
    var isInstructor: Bool {
        role == .teacher || role == .ta
    }

    /// 是否為學生
    var isStudent: Bool {
        role == .student
    }

    /// 是否可以管理課程內容
    var canManageContent: Bool {
        role.permissions.contains(.manageContent)
    }

    /// 是否可以評分
    var canGrade: Bool {
        role.permissions.contains(.grade)
    }

    /// 是否可以管理選課
    var canManageEnrollment: Bool {
        role.permissions.contains(.manageEnrollment)
    }

    /// 學習表現評級
    var performanceRating: PerformanceRating {
        let rate = assignmentCompletionRate
        if rate >= 0.9 { return .excellent }
        if rate >= 0.7 { return .good }
        if rate >= 0.5 { return .average }
        return .needsImprovement
    }
}

// MARK: - CourseRole (課程角色)

/// 課程中的角色，固定枚舉，權限預先定義
enum CourseRole: String, Codable, CaseIterable {
    case teacher        // 教師（擁有完整權限）
    case ta             // 助教（協助教學與評分）
    case student        // 學生（基本學習權限）
    case observer       // 旁聽生（只能觀看）

    var displayName: String {
        switch self {
        case .teacher: return "教師"
        case .ta: return "助教"
        case .student: return "學生"
        case .observer: return "旁聽生"
        }
    }

    var icon: String {
        switch self {
        case .teacher: return "person.fill.checkmark"
        case .ta: return "person.2.fill"
        case .student: return "person.fill"
        case .observer: return "eye.fill"
        }
    }

    var color: String {
        switch self {
        case .teacher: return "#DC2626"     // 紅色
        case .ta: return "#F59E0B"          // 橙色
        case .student: return "#3B82F6"     // 藍色
        case .observer: return "#6B7280"    // 灰色
        }
    }

    /// 角色權限
    var permissions: Set<CoursePermission> {
        switch self {
        case .teacher:
            return [
                .view, .post, .comment, .delete,
                .manageContent, .manageEnrollment,
                .grade, .takeAttendance,
                .createAssignment, .editSettings
            ]
        case .ta:
            return [
                .view, .post, .comment,
                .manageContent, .grade, .takeAttendance,
                .createAssignment
            ]
        case .student:
            return [
                .view, .comment, .submitAssignment,
                .viewGrades, .viewAttendance
            ]
        case .observer:
            return [.view]
        }
    }

    /// 檢查是否擁有特定權限
    func hasPermission(_ permission: CoursePermission) -> Bool {
        permissions.contains(permission)
    }
}

// MARK: - CoursePermission (課程權限)

/// 課程相關的權限
enum CoursePermission: String, CaseIterable {
    // 基本權限
    case view                   // 查看課程內容
    case post                   // 發布貼文/公告
    case comment                // 留言評論
    case delete                 // 刪除內容

    // 內容管理
    case manageContent          // 管理課程教材
    case createAssignment       // 建立作業
    case editSettings           // 編輯課程設定

    // 成員管理
    case manageEnrollment       // 管理選課名單

    // 評量權限
    case grade                  // 評分
    case takeAttendance         // 點名

    // 學生權限
    case submitAssignment       // 繳交作業
    case viewGrades             // 查看成績
    case viewAttendance         // 查看出席記錄

    var displayName: String {
        switch self {
        case .view: return "查看內容"
        case .post: return "發布貼文"
        case .comment: return "留言"
        case .delete: return "刪除內容"
        case .manageContent: return "管理教材"
        case .createAssignment: return "建立作業"
        case .editSettings: return "編輯設定"
        case .manageEnrollment: return "管理選課"
        case .grade: return "評分"
        case .takeAttendance: return "點名"
        case .submitAssignment: return "繳交作業"
        case .viewGrades: return "查看成績"
        case .viewAttendance: return "查看出席"
        }
    }
}

// MARK: - EnrollmentStatus (選課狀態)

enum EnrollmentStatus: String, Codable, CaseIterable {
    case active             // 活躍（正常選課）
    case pending            // 待審核（需要教師批准）
    case dropped            // 已退選
    case completed          // 已完成（課程結束）
    case suspended          // 暫停（例如休學）

    var displayName: String {
        switch self {
        case .active: return "進行中"
        case .pending: return "待審核"
        case .dropped: return "已退選"
        case .completed: return "已完成"
        case .suspended: return "已暫停"
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .dropped: return "xmark.circle.fill"
        case .completed: return "flag.checkered"
        case .suspended: return "pause.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .active: return "#10B981"      // 綠色
        case .pending: return "#F59E0B"     // 橙色
        case .dropped: return "#EF4444"     // 紅色
        case .completed: return "#3B82F6"   // 藍色
        case .suspended: return "#6B7280"   // 灰色
        }
    }
}

// MARK: - EnrollmentMethod (選課方式)

enum EnrollmentMethod: String, Codable {
    case selfEnroll         // 自行加選（使用邀請碼）
    case invited            // 教師邀請
    case adminAdded         // 管理員添加
    case imported           // 批次匯入

    var displayName: String {
        switch self {
        case .selfEnroll: return "自行加選"
        case .invited: return "教師邀請"
        case .adminAdded: return "管理員添加"
        case .imported: return "批次匯入"
        }
    }
}

// MARK: - PerformanceRating (學習表現評級)

enum PerformanceRating: String {
    case excellent          // 優秀
    case good              // 良好
    case average           // 普通
    case needsImprovement  // 需要加強

    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .average: return "普通"
        case .needsImprovement: return "需要加強"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "#10B981"       // 綠色
        case .good: return "#3B82F6"            // 藍色
        case .average: return "#F59E0B"         // 橙色
        case .needsImprovement: return "#EF4444" // 紅色
        }
    }
}

// MARK: - EnrollmentWithCourse (UI 輔助模型)

/// 包含課程資訊的選課記錄，方便 UI 顯示
struct EnrollmentWithCourse: Identifiable, Hashable {
    let enrollment: Enrollment
    let course: Course?

    var id: String {
        enrollment.id ?? UUID().uuidString
    }

    var courseName: String {
        course?.name ?? "未知課程"
    }

    var courseCode: String {
        course?.code ?? "N/A"
    }

    var semester: String {
        course?.semester ?? ""
    }

    var isActive: Bool {
        enrollment.status == .active && (course?.isActive ?? false)
    }
}

// MARK: - EnrollmentWithUser (UI 輔助模型)

/// 包含用戶資訊的選課記錄，方便顯示課程成員列表
struct EnrollmentWithUser: Identifiable, Hashable {
    let enrollment: Enrollment
    let user: UserProfile?

    var id: String {
        enrollment.id ?? UUID().uuidString
    }

    var displayName: String {
        enrollment.nickname ?? user?.name ?? "未知用戶"
    }

    var avatarUrl: String? {
        user?.avatarUrl
    }

    var email: String? {
        user?.email
    }
}
