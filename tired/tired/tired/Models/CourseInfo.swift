import Foundation
import FirebaseFirestoreSwift

/// 課程專屬資訊
/// 僅當 Organization.type == .course 時使用
struct CourseInfo: Codable, Hashable {
    var courseCode: String              // 課程代碼 (例如: "CS101", "IM201")
    var semester: String                // 學期 (例如: "2024-1" 表示 2024 學年第一學期)
    var academicYear: String            // 學年 (例如: "2024")
    var credits: Int                    // 學分數
    var syllabus: String?               // 課程大綱 (Markdown 格式)
    var courseLevel: String?            // 課程級別 (例如: "大學部", "研究所")
    var prerequisites: [String]?        // 先修課程 ID 列表
    var maxEnrollment: Int?             // 最大選課人數
    var currentEnrollment: Int          // 目前選課人數

    init(
        courseCode: String,
        semester: String,
        academicYear: String,
        credits: Int,
        syllabus: String? = nil,
        courseLevel: String? = nil,
        prerequisites: [String]? = nil,
        maxEnrollment: Int? = nil,
        currentEnrollment: Int = 0
    ) {
        self.courseCode = courseCode
        self.semester = semester
        self.academicYear = academicYear
        self.credits = credits
        self.syllabus = syllabus
        self.courseLevel = courseLevel
        self.prerequisites = prerequisites
        self.maxEnrollment = maxEnrollment
        self.currentEnrollment = currentEnrollment
    }
}
