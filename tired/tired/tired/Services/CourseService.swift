import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 課程管理服務
/// 負責課程的 CRUD 操作、查詢和統計
/// 基於新的 Course 模型設計，取代舊的基於 Organization 的課程管理
class CourseService {
    static let shared = CourseService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Constants

    private let coursesCollection = "courses"

    // MARK: - Create

    /// 創建新課程
    /// - Parameters:
    ///   - course: 課程資料
    ///   - creatorUserId: 建課教師 ID
    /// - Returns: 課程 ID
    func createCourse(_ course: Course) async throws -> String {
        var newCourse = course
        newCourse.createdAt = Date()
        newCourse.updatedAt = Date()
        newCourse.currentEnrollment = 0

        // 生成選課代碼（如果未提供）
        if newCourse.enrollmentCode == nil {
            newCourse.enrollmentCode = generateEnrollmentCode()
        }

        // 保存到 Firestore
        let docRef = try db.collection(coursesCollection).addDocument(from: newCourse)

        // 自動為建課教師創建 Enrollment（角色：教師）
        let enrollment = Enrollment(
            userId: newCourse.createdByUserId,
            courseId: docRef.documentID,
            role: .teacher,
            status: .active,
            enrollmentMethod: .adminAdded
        )

        try await EnrollmentService.shared.createEnrollment(enrollment)

        return docRef.documentID
    }

    /// 生成隨機選課代碼（8位大寫字母數字）
    private func generateEnrollmentCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }

    // MARK: - Read

    /// 獲取單一課程
    func fetchCourse(id: String) async throws -> Course {
        let document = try await db.collection(coursesCollection).document(id).getDocument()
        guard let course = try? document.data(as: Course.self) else {
            throw NSError(domain: "CourseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "課程不存在"])
        }
        return course
    }

    /// 獲取多個課程（批次）
    func fetchCourses(ids: [String]) async throws -> [String: Course] {
        var result: [String: Course] = [:]

        // Firestore 限制每次查詢最多 10 個 ID
        let chunks = ids.chunked(into: 10)

        for chunk in chunks {
            let snapshot = try await db.collection(coursesCollection)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                if let course = try? document.data(as: Course.self) {
                    result[document.documentID] = course
                }
            }
        }

        return result
    }

    /// 獲取用戶的所有課程（通過 Enrollment）
    func fetchUserCourses(userId: String, includeArchived: Bool = false) async throws -> [EnrollmentWithCourse] {
        // 1. 獲取用戶的所有 Enrollment
        let enrollments = try await EnrollmentService.shared.fetchUserEnrollments(userId: userId)

        // 2. 提取課程 ID
        let courseIds = enrollments.map { $0.courseId }

        // 3. 批次獲取課程資料
        let coursesDict = try await fetchCourses(ids: courseIds)

        // 4. 組合成 EnrollmentWithCourse
        var result: [EnrollmentWithCourse] = []
        for enrollment in enrollments {
            let course = coursesDict[enrollment.courseId]

            // 過濾已封存課程
            if !includeArchived, let course = course, course.isArchived {
                continue
            }

            result.append(EnrollmentWithCourse(enrollment: enrollment, course: course))
        }

        return result
    }

    /// 實時監聽用戶的課程列表
    func observeUserCourses(userId: String) -> AnyPublisher<[EnrollmentWithCourse], Error> {
        // 使用 Combine 將異步任務轉換為 Publisher
        return Future<[EnrollmentWithCourse], Error> { promise in
            Task {
                do {
                    let courses = try await self.fetchUserCourses(userId: userId)
                    promise(.success(courses))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// 按學期獲取課程
    func fetchCoursesBySemester(semester: String, institutionId: String? = nil) async throws -> [Course] {
        var query: Query = db.collection(coursesCollection)
            .whereField("semester", isEqualTo: semester)
            .whereField("isArchived", isEqualTo: false)

        if let institutionId = institutionId {
            query = query.whereField("institutionId", isEqualTo: institutionId)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Course.self) }
    }

    /// 搜索公開課程
    func searchPublicCourses(keyword: String, limit: Int = 20) async throws -> [Course] {
        // Firestore 不支持全文搜索，這裡只能做簡單的前綴匹配
        // 實際應用中建議使用 Algolia 等專門的搜索服務

        let snapshot = try await db.collection(coursesCollection)
            .whereField("isPublic", isEqualTo: true)
            .whereField("isArchived", isEqualTo: false)
            .limit(to: limit)
            .getDocuments()

        let allCourses = snapshot.documents.compactMap { try? $0.data(as: Course.self) }

        // 客戶端過濾
        let lowercasedKeyword = keyword.lowercased()
        return allCourses.filter { course in
            course.name.lowercased().contains(lowercasedKeyword) ||
            course.code.lowercased().contains(lowercasedKeyword)
        }
    }

    // MARK: - Update

    /// 更新課程資料
    func updateCourse(_ course: Course) async throws {
        guard let courseId = course.id else {
            throw NSError(domain: "CourseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "課程 ID 不能為空"])
        }

        var updatedCourse = course
        updatedCourse.updatedAt = Date()

        try db.collection(coursesCollection).document(courseId).setData(from: updatedCourse, merge: true)
    }

    /// 更新課程統計資料
    func updateCourseStats(courseId: String, currentEnrollment: Int? = nil, totalAssignments: Int? = nil, totalAnnouncements: Int? = nil) async throws {
        var updateData: [String: Any] = ["updatedAt": Timestamp(date: Date())]

        if let enrollment = currentEnrollment {
            updateData["currentEnrollment"] = enrollment
        }
        if let assignments = totalAssignments {
            updateData["totalAssignments"] = assignments
        }
        if let announcements = totalAnnouncements {
            updateData["totalAnnouncements"] = announcements
        }

        try await db.collection(coursesCollection).document(courseId).updateData(updateData)
    }

    /// 增加選課人數
    func incrementEnrollmentCount(courseId: String) async throws {
        try await db.collection(coursesCollection).document(courseId).updateData([
            "currentEnrollment": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 減少選課人數
    func decrementEnrollmentCount(courseId: String) async throws {
        try await db.collection(coursesCollection).document(courseId).updateData([
            "currentEnrollment": FieldValue.increment(Int64(-1)),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 封存課程
    func archiveCourse(courseId: String) async throws {
        try await db.collection(coursesCollection).document(courseId).updateData([
            "isArchived": true,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 解除封存
    func unarchiveCourse(courseId: String) async throws {
        try await db.collection(coursesCollection).document(courseId).updateData([
            "isArchived": false,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Delete

    /// 刪除課程（軟刪除：封存）
    func deleteCourse(courseId: String, userId: String) async throws {
        // 1. 檢查權限（必須是建課教師）
        let course = try await fetchCourse(id: courseId)
        guard course.createdByUserId == userId else {
            throw NSError(domain: "CourseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "只有建課教師可以刪除課程"])
        }

        // 2. 軟刪除：封存課程而非真正刪除
        try await archiveCourse(courseId: courseId)

        // 3. （可選）將所有選課記錄標記為 completed
        // 留給 EnrollmentService 處理
    }

    /// 永久刪除課程（危險操作）
    func permanentlyDeleteCourse(courseId: String, userId: String) async throws {
        // 1. 檢查權限
        let course = try await fetchCourse(id: courseId)
        guard course.createdByUserId == userId else {
            throw NSError(domain: "CourseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "只有建課教師可以刪除課程"])
        }

        // 2. 刪除所有相關的 Enrollment
        try await EnrollmentService.shared.deleteAllEnrollments(courseId: courseId)

        // 3. 刪除課程文檔
        try await db.collection(coursesCollection).document(courseId).delete()

        // TODO: 刪除課程相關的子集合（教材、作業、公告等）
    }

    // MARK: - Enrollment Code

    /// 通過選課代碼查找課程
    func findCourseByEnrollmentCode(_ code: String) async throws -> Course? {
        let snapshot = try await db.collection(coursesCollection)
            .whereField("enrollmentCode", isEqualTo: code.uppercased())
            .whereField("isArchived", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        return try? document.data(as: Course.self)
    }

    /// 重新生成選課代碼
    func regenerateEnrollmentCode(courseId: String) async throws -> String {
        let newCode = generateEnrollmentCode()

        try await db.collection(coursesCollection).document(courseId).updateData([
            "enrollmentCode": newCode,
            "updatedAt": Timestamp(date: Date())
        ])

        return newCode
    }

    // MARK: - Statistics

    /// 獲取課程統計資料
    func fetchCourseStatistics(courseId: String) async throws -> CourseStatistics {
        let course = try await fetchCourse(id: courseId)
        let enrollments = try await EnrollmentService.shared.fetchCourseEnrollments(courseId: courseId)

        let teacherCount = enrollments.filter { $0.role == .teacher }.count
        let taCount = enrollments.filter { $0.role == .ta }.count
        let studentCount = enrollments.filter { $0.role == .student }.count
        let observerCount = enrollments.filter { $0.role == .observer }.count

        let activeCount = enrollments.filter { $0.status == .active }.count
        let completedCount = enrollments.filter { $0.status == .completed }.count
        let droppedCount = enrollments.filter { $0.status == .dropped }.count

        return CourseStatistics(
            courseId: courseId,
            courseName: course.name,
            totalEnrollments: enrollments.count,
            teacherCount: teacherCount,
            taCount: taCount,
            studentCount: studentCount,
            observerCount: observerCount,
            activeCount: activeCount,
            completedCount: completedCount,
            droppedCount: droppedCount,
            totalAssignments: course.totalAssignments,
            totalAnnouncements: course.totalAnnouncements
        )
    }

    // MARK: - Utilities

    /// 獲取當前學期
    static func getCurrentSemester() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        // 假設第一學期是 9-1 月，第二學期是 2-6 月
        let semester = (month >= 9 || month <= 1) ? 1 : 2

        return "\(year)-\(semester)"
    }

    /// 獲取當前學年
    static func getCurrentAcademicYear() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        // 如果月份在 9-12 月，學年是當年；1-8 月，學年是前一年
        if month >= 9 {
            return "\(year)"
        } else {
            return "\(year - 1)"
        }
    }
}

// MARK: - Helper Extensions

extension Array {
    /// 將陣列分割成指定大小的區塊
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - CourseStatistics

/// 課程統計資料
struct CourseStatistics {
    let courseId: String
    let courseName: String

    // 選課統計
    let totalEnrollments: Int
    let teacherCount: Int
    let taCount: Int
    let studentCount: Int
    let observerCount: Int

    // 狀態統計
    let activeCount: Int
    let completedCount: Int
    let droppedCount: Int

    // 內容統計
    let totalAssignments: Int
    let totalAnnouncements: Int

    /// 退選率
    var dropRate: Double {
        guard totalEnrollments > 0 else { return 0.0 }
        return Double(droppedCount) / Double(totalEnrollments)
    }

    /// 完成率
    var completionRate: Double {
        guard totalEnrollments > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalEnrollments)
    }
}

