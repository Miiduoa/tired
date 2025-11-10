import Foundation

// MARK: - Term Config Model
struct TermConfig: Codable, Identifiable {
    var id: String
    var userId: String
    var termId: String // e.g., "113-1", "113-2", "113-summer", "personal-default"

    // Date Range
    var startDate: Date?
    var endDate: Date?

    // Status
    var isHolidayPeriod: Bool // true for summer/winter breaks or non-student mode

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        termId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isHolidayPeriod: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.termId = termId
        self.startDate = startDate
        self.endDate = endDate
        self.isHolidayPeriod = isHolidayPeriod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Term Config Helpers
extension TermConfig {
    // Check if current date is within term
    func isActive(on date: Date = Date()) -> Bool {
        if let start = startDate, date < start {
            return false
        }
        if let end = endDate, date > end {
            return false
        }
        return true
    }

    // Display name
    var displayName: String {
        if termId == "personal-default" {
            return "個人模式"
        }

        // Parse academic term format: "113-1" -> "113學年第1學期"
        let components = termId.split(separator: "-")
        if components.count == 2 {
            let year = components[0]
            let semester = components[1]

            switch semester {
            case "1":
                return "\(year)學年第1學期"
            case "2":
                return "\(year)學年第2學期"
            case "summer":
                return "\(year)學年暑假"
            case "winter":
                return "\(year)學年寒假"
            default:
                return termId
            }
        }

        return termId
    }

    // Check if this is a pseudo-term (non-student mode)
    var isPseudoTerm: Bool {
        return termId == "personal-default"
    }

    // Check if this is an academic term (not holiday)
    var isAcademicTerm: Bool {
        return !isHolidayPeriod && !isPseudoTerm
    }
}

// MARK: - User Status
enum UserStatus: String, Codable, CaseIterable {
    case currentStudent = "current_student"          // 在學中
    case preparingExam = "preparing_exam"            // 準備升學/考試中
    case graduated = "graduated"                      // 已畢業/先工作一陣子

    var displayText: String {
        switch self {
        case .currentStudent:
            return "在學中"
        case .preparingExam:
            return "準備升學/考試中"
        case .graduated:
            return "已畢業/先工作一陣子"
        }
    }

    var needsAcademicFeatures: Bool {
        return self == .currentStudent
    }
}
