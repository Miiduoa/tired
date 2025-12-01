import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 選課/註冊管理服務
/// 負責管理用戶與課程的關係
class EnrollmentService {
    static let shared = EnrollmentService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Constants

    private let enrollmentsCollection = "enrollments"

    // MARK: - Create

    /// 創建選課記錄
    func createEnrollment(_ enrollment: Enrollment) async throws {
        var newEnrollment = enrollment
        newEnrollment.enrolledAt = Date()
        newEnrollment.updatedAt = Date()

        let docRef = try db.collection(enrollmentsCollection).addDocument(from: newEnrollment)

        // 更新課程的選課人數
        try await CourseService.shared.incrementEnrollmentCount(courseId: enrollment.courseId)
    }

    /// 學生通過選課代碼加入課程
    func enrollByCourseCode(_ code: String, userId: String) async throws -> String {
        // 1. 查找課程
        guard let course = try await CourseService.shared.findCourseByEnrollmentCode(code) else {
            throw NSError(domain: "EnrollmentService", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到課程或選課代碼無效"])
        }

        guard let courseId = course.id else {
            throw NSError(domain: "EnrollmentService", code: 400, userInfo: [NSLocalizedDescriptionKey: "課程 ID 無效"])
        }

        // 2. 檢查是否已選課
        if let existingEnrollment = try await fetchEnrollment(userId: userId, courseId: courseId) {
            if existingEnrollment.status == .active {
                throw NSError(domain: "EnrollmentService", code: 409, userInfo: [NSLocalizedDescriptionKey: "您已經選過這門課程"])
            }
        }

        // 3. 檢查是否已滿
        if course.isFull {
            throw NSError(domain: "EnrollmentService", code: 403, userInfo: [NSLocalizedDescriptionKey: "課程已額滿"])
        }

        // 4. 創建選課記錄（預設為學生）
        let enrollment = Enrollment(
            userId: userId,
            courseId: courseId,
            role: .student,
            status: .active,
            enrollmentMethod: .selfEnroll
        )

        try await createEnrollment(enrollment)

        return courseId
    }

    // MARK: - Read

    /// 獲取特定用戶在特定課程的選課記錄
    func fetchEnrollment(userId: String, courseId: String) async throws -> Enrollment? {
        let snapshot = try await db.collection(enrollmentsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("courseId", isEqualTo: courseId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        return try? document.data(as: Enrollment.self)
    }

    /// 獲取用戶的所有選課記錄
    func fetchUserEnrollments(userId: String, status: EnrollmentStatus? = nil) async throws -> [Enrollment] {
        var query: Query = db.collection(enrollmentsCollection)
            .whereField("userId", isEqualTo: userId)

        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Enrollment.self) }
    }

    /// 獲取課程的所有選課記錄
    func fetchCourseEnrollments(courseId: String, role: CourseRole? = nil) async throws -> [Enrollment] {
        var query: Query = db.collection(enrollmentsCollection)
            .whereField("courseId", isEqualTo: courseId)

        if let role = role {
            query = query.whereField("role", isEqualTo: role.rawValue)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Enrollment.self) }
    }

    /// 獲取課程的所有學生（包含用戶資料）
    func fetchCourseStudentsWithProfile(courseId: String) async throws -> [EnrollmentWithUser] {
        let enrollments = try await fetchCourseEnrollments(courseId: courseId)
        let studentEnrollments = enrollments.filter { $0.role == .student && $0.status == .active }

        var result: [EnrollmentWithUser] = []
        for enrollment in studentEnrollments {
            // 獲取用戶資料
            let user = try? await UserService.shared.getUserProfile(userId: enrollment.userId)
            result.append(EnrollmentWithUser(enrollment: enrollment, user: user))
        }

        return result
    }

    /// 實時監聽課程的選課列表
    func observeCourseEnrollments(courseId: String) -> AnyPublisher<[Enrollment], Error> {
        let subject = PassthroughSubject<[Enrollment], Error>()

        db.collection(enrollmentsCollection)
            .whereField("courseId", isEqualTo: courseId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let enrollments = documents.compactMap { try? $0.data(as: Enrollment.self) }
                subject.send(enrollments)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Update

    /// 更新選課記錄
    func updateEnrollment(_ enrollment: Enrollment) async throws {
        guard let enrollmentId = enrollment.id else {
            throw NSError(domain: "EnrollmentService", code: 400, userInfo: [NSLocalizedDescriptionKey: "選課記錄 ID 無效"])
        }

        var updatedEnrollment = enrollment
        updatedEnrollment.updatedAt = Date()

        try db.collection(enrollmentsCollection).document(enrollmentId).setData(from: updatedEnrollment, merge: true)
    }

    /// 更新用戶在課程中的角色
    func updateEnrollmentRole(enrollmentId: String, newRole: CourseRole) async throws {
        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData([
            "role": newRole.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 更新選課狀態
    func updateEnrollmentStatus(enrollmentId: String, newStatus: EnrollmentStatus) async throws {
        var updateData: [String: Any] = [
            "status": newStatus.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]

        // 如果是退選，記錄退選時間
        if newStatus == .dropped {
            updateData["droppedAt"] = Timestamp(date: Date())
        } else if newStatus == .completed {
            updateData["completedAt"] = Timestamp(date: Date())
        }

        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData(updateData)
    }

    /// 更新成績
    func updateGrade(enrollmentId: String, finalGrade: Double, letterGrade: String?) async throws {
        var updateData: [String: Any] = [
            "finalGrade": finalGrade,
            "updatedAt": Timestamp(date: Date())
        ]

        if let letterGrade = letterGrade {
            updateData["letterGrade"] = letterGrade
        }

        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData(updateData)
    }

    /// 更新作業完成統計
    func updateAssignmentStats(enrollmentId: String, completedAssignments: Int? = nil, submittedOnTime: Int? = nil, lateSubmissions: Int? = nil) async throws {
        var updateData: [String: Any] = ["updatedAt": Timestamp(date: Date())]

        if let completed = completedAssignments {
            updateData["completedAssignments"] = completed
        }
        if let onTime = submittedOnTime {
            updateData["submittedOnTime"] = onTime
        }
        if let late = lateSubmissions {
            updateData["lateSubmissions"] = late
        }

        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData(updateData)
    }

    /// 更新出席統計
    func updateAttendanceStats(enrollmentId: String, totalAbsences: Int? = nil, attendanceRate: Double? = nil) async throws {
        var updateData: [String: Any] = ["updatedAt": Timestamp(date: Date())]

        if let absences = totalAbsences {
            updateData["totalAbsences"] = absences
        }
        if let rate = attendanceRate {
            updateData["attendanceRate"] = rate
        }

        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData(updateData)
    }

    /// 增加缺席次數
    func incrementAbsences(enrollmentId: String) async throws {
        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData([
            "totalAbsences": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 更新最後存取時間
    func updateLastAccessedAt(userId: String, courseId: String) async throws {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId),
              let enrollmentId = enrollment.id else {
            return
        }

        try await db.collection(enrollmentsCollection).document(enrollmentId).updateData([
            "lastAccessedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Delete

    /// 退選課程
    func dropCourse(userId: String, courseId: String) async throws {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId),
              let enrollmentId = enrollment.id else {
            throw NSError(domain: "EnrollmentService", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到選課記錄"])
        }

        // 檢查是否為教師（教師不能退選自己的課）
        guard enrollment.role != .teacher else {
            throw NSError(domain: "EnrollmentService", code: 403, userInfo: [NSLocalizedDescriptionKey: "教師不能退選自己的課程"])
        }

        // 更新狀態為已退選
        try await updateEnrollmentStatus(enrollmentId: enrollmentId, newStatus: .dropped)

        // 減少課程選課人數
        try await CourseService.shared.decrementEnrollmentCount(courseId: courseId)
    }

    /// 刪除選課記錄（管理員操作）
    func deleteEnrollment(enrollmentId: String) async throws {
        // 獲取選課記錄以更新課程統計
        let document = try await db.collection(enrollmentsCollection).document(enrollmentId).getDocument()
        guard let enrollment = try? document.data(as: Enrollment.self) else {
            throw NSError(domain: "EnrollmentService", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到選課記錄"])
        }

        // 刪除記錄
        try await db.collection(enrollmentsCollection).document(enrollmentId).delete()

        // 如果是活躍狀態，需要減少課程人數
        if enrollment.status == .active {
            try await CourseService.shared.decrementEnrollmentCount(courseId: enrollment.courseId)
        }
    }

    /// 刪除課程的所有選課記錄（刪除課程時使用）
    func deleteAllEnrollments(courseId: String) async throws {
        let enrollments = try await fetchCourseEnrollments(courseId: courseId)

        for enrollment in enrollments {
            if let id = enrollment.id {
                try await db.collection(enrollmentsCollection).document(id).delete()
            }
        }
    }

    // MARK: - Permission Checks

    /// 檢查用戶在課程中是否有特定權限
    func checkPermission(userId: String, courseId: String, permission: CoursePermission) async throws -> Bool {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId) else {
            return false
        }

        // 只有活躍狀態才有權限
        guard enrollment.status == .active else {
            return false
        }

        return enrollment.role.hasPermission(permission)
    }

    /// 檢查用戶是否為課程教師
    func isTeacher(userId: String, courseId: String) async throws -> Bool {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId) else {
            return false
        }

        return enrollment.role == .teacher && enrollment.status == .active
    }

    /// 檢查用戶是否為課程學生
    func isStudent(userId: String, courseId: String) async throws -> Bool {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId) else {
            return false
        }

        return enrollment.role == .student && enrollment.status == .active
    }

    /// 檢查用戶是否可以查看課程
    func canAccessCourse(userId: String, courseId: String) async throws -> Bool {
        guard let enrollment = try await fetchEnrollment(userId: userId, courseId: courseId) else {
            return false
        }

        return enrollment.status == .active || enrollment.status == .completed
    }

    // MARK: - Statistics

    /// 獲取用戶的課程統計
    func fetchUserCourseStats(userId: String) async throws -> UserCourseStatistics {
        let enrollments = try await fetchUserEnrollments(userId: userId)

        let activeCount = enrollments.filter { $0.status == .active }.count
        let completedCount = enrollments.filter { $0.status == .completed }.count
        let droppedCount = enrollments.filter { $0.status == .dropped }.count

        let teachingCount = enrollments.filter { $0.role == .teacher && $0.status == .active }.count
        let learningCount = enrollments.filter { $0.role == .student && $0.status == .active }.count

        // 計算平均成績（只計算有成績的課程）
        let gradesEnrollments = enrollments.filter { $0.finalGrade != nil }
        let averageGrade: Double?
        if !gradesEnrollments.isEmpty {
            let totalGrade = gradesEnrollments.compactMap { $0.finalGrade }.reduce(0, +)
            averageGrade = totalGrade / Double(gradesEnrollments.count)
        } else {
            averageGrade = nil
        }

        return UserCourseStatistics(
            userId: userId,
            totalEnrollments: enrollments.count,
            activeCount: activeCount,
            completedCount: completedCount,
            droppedCount: droppedCount,
            teachingCount: teachingCount,
            learningCount: learningCount,
            averageGrade: averageGrade
        )
    }
}

// MARK: - UserCourseStatistics

/// 用戶的課程統計資料
struct UserCourseStatistics {
    let userId: String
    let totalEnrollments: Int
    let activeCount: Int
    let completedCount: Int
    let droppedCount: Int
    let teachingCount: Int      // 正在教授的課程數
    let learningCount: Int      // 正在學習的課程數
    let averageGrade: Double?   // 平均成績

    /// 完成率
    var completionRate: Double {
        guard totalEnrollments > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalEnrollments)
    }

    /// 退選率
    var dropRate: Double {
        guard totalEnrollments > 0 else { return 0.0 }
        return Double(droppedCount) / Double(totalEnrollments)
    }
}
