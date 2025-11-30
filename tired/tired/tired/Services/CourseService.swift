import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 課程管理服務 - 擴展組織服務以支援課程功能
class CourseService: ObservableObject {
    private let db = FirebaseManager.shared.db
    
    // MARK: - Course Schedule Management
    
    /// 創建課程時間表
    func createCourseSchedule(_ schedule: CourseSchedule) async throws -> CourseSchedule {
        var newSchedule = schedule
        newSchedule.updatedAt = Date()
        
        let docRef = try db.collection("organizations")
            .document(schedule.organizationId)
            .collection("schedules")
            .addDocument(from: newSchedule)
        
        var createdSchedule = newSchedule
        createdSchedule.id = docRef.documentID
        return createdSchedule
    }
    
    /// 獲取組織的課程時間表（實時監聽）
    func getCourseSchedules(organizationId: String) -> AnyPublisher<[CourseSchedule], Error> {
        let subject = PassthroughSubject<[CourseSchedule], Error>()
        
        db.collection("organizations")
            .document(organizationId)
            .collection("schedules")
            .order(by: "dayOfWeek", descending: false)
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let schedules = documents.compactMap { doc -> CourseSchedule? in
                    try? doc.data(as: CourseSchedule.self)
                }
                
                subject.send(schedules)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 更新課程時間表
    func updateCourseSchedule(scheduleId: String, organizationId: String, updates: [String: Any]) async throws {
        var finalUpdates = updates
        finalUpdates["updatedAt"] = Timestamp(date: Date())
        
        try await db.collection("organizations")
            .document(organizationId)
            .collection("schedules")
            .document(scheduleId)
            .updateData(finalUpdates)
    }
    
    /// 刪除課程時間表
    func deleteCourseSchedule(scheduleId: String, organizationId: String) async throws {
        try await db.collection("organizations")
            .document(organizationId)
            .collection("schedules")
            .document(scheduleId)
            .delete()
    }
    
    // MARK: - Course Information Management
    
    /// 更新課程資訊
    func updateCourseInfo(
        organizationId: String,
        courseCode: String? = nil,
        semester: String? = nil,
        credits: Int? = nil,
        syllabus: String? = nil,
        academicYear: String? = nil,
        courseLevel: String? = nil,
        prerequisites: [String]? = nil,
        maxEnrollment: Int? = nil
    ) async throws {
        var updates: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let courseCode = courseCode {
            updates["courseCode"] = courseCode
        }
        if let semester = semester {
            updates["semester"] = semester
        }
        if let credits = credits {
            updates["credits"] = credits
        }
        if let syllabus = syllabus {
            updates["syllabus"] = syllabus
        }
        if let academicYear = academicYear {
            updates["academicYear"] = academicYear
        }
        if let courseLevel = courseLevel {
            updates["courseLevel"] = courseLevel
        }
        if let prerequisites = prerequisites {
            updates["prerequisites"] = prerequisites
        }
        if let maxEnrollment = maxEnrollment {
            updates["maxEnrollment"] = maxEnrollment
        }
        
        try await db.collection("organizations")
            .document(organizationId)
            .updateData(updates)
    }
    
    /// 更新選課人數
    func updateEnrollment(organizationId: String, increment: Int = 1) async throws {
        let orgRef = db.collection("organizations").document(organizationId)
        
        try await orgRef.updateData([
            "currentEnrollment": FieldValue.increment(Int64(increment)),
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// 獲取課程的完整資訊（包含時間表）
    func getCourseWithSchedule(organizationId: String) async throws -> (organization: Organization, schedules: [CourseSchedule]) {
        // 獲取組織資訊
        let orgDoc = try await db.collection("organizations")
            .document(organizationId)
            .getDocument()
        
        var organization = try orgDoc.data(as: Organization.self)
        organization.id = organizationId
        
        // 獲取時間表
        let schedulesSnapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("schedules")
            .order(by: "dayOfWeek", descending: false)
            .order(by: "startTime", descending: false)
            .getDocuments()
        
        let schedules = try schedulesSnapshot.documents.compactMap { doc -> CourseSchedule? in
            try? doc.data(as: CourseSchedule.self)
        }
        
        return (organization, schedules)
    }
    
    // MARK: - Course Utilities
    
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
    
    /// 檢查是否可選課（檢查先修課程、人數限制等）
    func canEnroll(userId: String, organizationId: String) async throws -> (canEnroll: Bool, reason: String?) {
        // 獲取組織資訊
        let orgDoc = try await db.collection("organizations")
            .document(organizationId)
            .getDocument()
        
        guard let orgData = orgDoc.data() else {
            return (false, "找不到課程資訊")
        }
        
        // 檢查人數限制
        if let maxEnrollment = orgData["maxEnrollment"] as? Int,
           let currentEnrollment = orgData["currentEnrollment"] as? Int,
           currentEnrollment >= maxEnrollment {
            return (false, "課程已額滿")
        }
        
        // 檢查先修課程
        if let prerequisites = orgData["prerequisites"] as? [String], !prerequisites.isEmpty {
            // 檢查用戶是否已完成所有先修課程
            let membershipsSnapshot = try await db.collection("memberships")
                .whereField("userId", isEqualTo: userId)
                .whereField("organizationId", in: prerequisites)
                .getDocuments()
            
            let completedPrerequisites = Set(membershipsSnapshot.documents.map { $0.documentID })
            let requiredPrerequisites = Set(prerequisites)
            
            if !requiredPrerequisites.isSubset(of: completedPrerequisites) {
                let missing = requiredPrerequisites.subtracting(completedPrerequisites)
                return (false, "尚未完成先修課程")
            }
        }
        
        return (true, nil)
    }
}

