import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Course (課程核心模型)

/// 課程是系統的核心實體，代表一個教學班級
/// 參考 TronClass/Moodle 等成熟 LMS 的設計理念
struct Course: Codable, Identifiable, Hashable {
    @DocumentID var id: String?

    // MARK: - 基本資訊
    var name: String                    // 課程名稱 (例如: "資料結構與演算法")
    var code: String                    // 課程代碼 (例如: "CS101")
    var description: String?            // 課程描述

    // MARK: - 所屬機構
    var institutionId: String?          // 所屬學校/機構 ID（目前可以是 organizationId）
    var institutionName: String?        // 機構名稱（冗餘儲存，方便顯示）
    var department: String?             // 系所名稱（作為標籤，不是層級關係）

    // MARK: - 學期資訊
    var semester: String                // 學期 (例如: "2024春季", "113-1")
    var academicYear: String            // 學年 (例如: "2024", "113")
    var startDate: Date?                // 開課日期
    var endDate: Date?                  // 結課日期

    // MARK: - 課程設定
    var credits: Int?                   // 學分數
    var courseLevel: CourseLevel        // 課程級別
    var language: String?               // 授課語言
    var maxEnrollment: Int?             // 最大選課人數
    var isPublic: Bool                  // 是否公開可見
    var isArchived: Bool                // 是否已封存
    var enrollmentCode: String?         // 選課代碼（類似邀請碼）

    // MARK: - 課程內容
    var syllabus: String?               // 課程大綱 (Markdown 格式)
    var objectives: [String]?           // 課程目標
    var prerequisites: [String]?        // 先修課程要求（描述）
    var textbooks: [String]?            // 教科書列表

    // MARK: - 視覺與品牌
    var coverImageUrl: String?          // 課程封面圖片
    var color: String?                  // 課程主題色 (Hex)

    // MARK: - 課表
    var schedule: [CourseSchedule]      // 上課時間表

    // MARK: - 統計資訊
    var currentEnrollment: Int          // 目前選課人數
    var totalAssignments: Int           // 作業總數
    var totalAnnouncements: Int         // 公告總數

    // MARK: - 時間戳記
    var createdAt: Date
    var updatedAt: Date
    var createdByUserId: String         // 建課教師

    enum CodingKeys: String, CodingKey {
        case id, name, code, description
        case institutionId, institutionName, department
        case semester, academicYear, startDate, endDate
        case credits, courseLevel, language, maxEnrollment, isPublic, isArchived, enrollmentCode
        case syllabus, objectives, prerequisites, textbooks
        case coverImageUrl, color
        case schedule
        case currentEnrollment, totalAssignments, totalAnnouncements
        case createdAt, updatedAt, createdByUserId
    }

    init(
        id: String? = nil,
        name: String,
        code: String,
        description: String? = nil,
        institutionId: String? = nil,
        institutionName: String? = nil,
        department: String? = nil,
        semester: String,
        academicYear: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        credits: Int? = nil,
        courseLevel: CourseLevel = .undergraduate,
        language: String? = "中文",
        maxEnrollment: Int? = nil,
        isPublic: Bool = false,
        isArchived: Bool = false,
        enrollmentCode: String? = nil,
        syllabus: String? = nil,
        objectives: [String]? = nil,
        prerequisites: [String]? = nil,
        textbooks: [String]? = nil,
        coverImageUrl: String? = nil,
        color: String? = nil,
        schedule: [CourseSchedule] = [],
        currentEnrollment: Int = 0,
        totalAssignments: Int = 0,
        totalAnnouncements: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdByUserId: String
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.description = description
        self.institutionId = institutionId
        self.institutionName = institutionName
        self.department = department
        self.semester = semester
        self.academicYear = academicYear
        self.startDate = startDate
        self.endDate = endDate
        self.credits = credits
        self.courseLevel = courseLevel
        self.language = language
        self.maxEnrollment = maxEnrollment
        self.isPublic = isPublic
        self.isArchived = isArchived
        self.enrollmentCode = enrollmentCode
        self.syllabus = syllabus
        self.objectives = objectives
        self.prerequisites = prerequisites
        self.textbooks = textbooks
        self.coverImageUrl = coverImageUrl
        self.color = color
        self.schedule = schedule
        self.currentEnrollment = currentEnrollment
        self.totalAssignments = totalAssignments
        self.totalAnnouncements = totalAnnouncements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
    }
}

// MARK: - Course Extensions

extension Course {
    /// 是否正在進行中
    var isActive: Bool {
        guard !isArchived else { return false }
        guard let start = startDate, let end = endDate else { return true }
        let now = Date()
        return now >= start && now <= end
    }

    /// 是否已結束
    var isCompleted: Bool {
        guard let end = endDate else { return false }
        return Date() > end
    }

    /// 是否即將開始（7天內）
    var isUpcoming: Bool {
        guard let start = startDate else { return false }
        let now = Date()
        let daysUntilStart = Calendar.current.dateComponents([.day], from: now, to: start).day ?? 0
        return daysUntilStart > 0 && daysUntilStart <= 7
    }

    /// 是否已滿
    var isFull: Bool {
        guard let max = maxEnrollment else { return false }
        return currentEnrollment >= max
    }

    /// 剩餘名額
    var remainingSeats: Int? {
        guard let max = maxEnrollment else { return nil }
        return max - currentEnrollment
    }

    /// 課程狀態描述
    var statusDescription: String {
        if isArchived { return "已封存" }
        if isCompleted { return "已結束" }
        if isUpcoming { return "即將開始" }
        if isActive { return "進行中" }
        return "未開始"
    }

    /// 完整課程標題（包含學期）
    var fullTitle: String {
        "\(name) (\(semester))"
    }

    /// 顯示用的系所資訊
    var departmentDisplay: String {
        department ?? institutionName ?? "未分類"
    }
}

// MARK: - CourseLevel (課程級別)

enum CourseLevel: String, Codable, CaseIterable {
    case undergraduate = "undergraduate"    // 大學部
    case graduate = "graduate"              // 研究所
    case doctoral = "doctoral"              // 博士班
    case professional = "professional"      // 專業培訓
    case continuing = "continuing"          // 進修推廣
    case k12 = "k12"                       // 國高中
    case other = "other"                   // 其他

    var displayName: String {
        switch self {
        case .undergraduate: return "大學部"
        case .graduate: return "研究所"
        case .doctoral: return "博士班"
        case .professional: return "專業培訓"
        case .continuing: return "進修推廣"
        case .k12: return "國高中"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .undergraduate: return "graduationcap"
        case .graduate: return "book.closed"
        case .doctoral: return "brain"
        case .professional: return "briefcase"
        case .continuing: return "person.2"
        case .k12: return "pencil"
        case .other: return "ellipsis"
        }
    }
}

// MARK: - CourseSchedule (保持與原有定義一致)

struct CourseSchedule: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var dayOfWeek: Int              // 1=週日, 2=週一, ..., 7=週六
    var startTime: String           // "09:00"
    var endTime: String             // "10:30"
    var location: String?           // 教室位置
    var roomNumber: String?         // 教室號碼
    var building: String?           // 建築物名稱
    var notes: String?              // 備註

    init(
        id: String = UUID().uuidString,
        dayOfWeek: Int,
        startTime: String,
        endTime: String,
        location: String? = nil,
        roomNumber: String? = nil,
        building: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.roomNumber = roomNumber
        self.building = building
        self.notes = notes
    }

    var dayName: String {
        let days = ["", "週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "未知" }
        return days[dayOfWeek]
    }

    var timeRange: String {
        "\(startTime) - \(endTime)"
    }

    var locationDisplay: String {
        if let building = building, let room = roomNumber {
            return "\(building) \(room)"
        } else if let location = location {
            return location
        }
        return "未指定地點"
    }
}
