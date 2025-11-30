import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Grade (成績模型)

/// 成績模型 - 支援多種評分方式（分數、等級、通過/不通過）
struct Grade: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    // 關聯資訊
    var taskId: String?              // 關聯的任務/作業 ID
    var userId: String               // 學員 ID
    var organizationId: String       // 組織/課程 ID
    var gradeItemId: String?         // 成績項目 ID（用於計算總成績）
    
    // 評分資訊
    var score: Double?               // 分數（可選，如果使用等級評分則為 nil）
    var maxScore: Double              // 滿分
    var percentage: Double?           // 百分比（自動計算：score / maxScore * 100）
    
    // 等級評分（可選）
    var grade: LetterGrade?           // 等級（A, B, C, D, F）
    var isPass: Bool?                // 通過/不通過（用於二元評分）
    
    // 評語和反饋
    var feedback: String?             // 評語
    var rubricScores: [RubricScore]? // 評分標準細項（用於詳細評分）
    
    // 評分者資訊
    var gradedBy: String              // 評分者 ID
    var gradedAt: Date?              // 評分時間
    
    // 狀態
    var status: GradeStatus           // 成績狀態
    var isReleased: Bool              // 是否已發布給學員
    
    // 時間戳記
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId
        case userId
        case organizationId
        case gradeItemId
        case score
        case maxScore
        case percentage
        case grade
        case isPass
        case feedback
        case rubricScores
        case gradedBy
        case gradedAt
        case status
        case isReleased
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        taskId: String? = nil,
        userId: String,
        organizationId: String,
        gradeItemId: String? = nil,
        score: Double? = nil,
        maxScore: Double,
        percentage: Double? = nil,
        grade: LetterGrade? = nil,
        isPass: Bool? = nil,
        feedback: String? = nil,
        rubricScores: [RubricScore]? = nil,
        gradedBy: String,
        gradedAt: Date? = nil,
        status: GradeStatus = .pending,
        isReleased: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.organizationId = organizationId
        self.gradeItemId = gradeItemId
        self.score = score
        self.maxScore = maxScore
        self.percentage = percentage ?? (score != nil ? (score! / maxScore * 100) : nil)
        self.grade = grade
        self.isPass = isPass
        self.feedback = feedback
        self.rubricScores = rubricScores
        self.gradedBy = gradedBy
        self.gradedAt = gradedAt
        self.status = status
        self.isReleased = isReleased
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Grade Extensions

extension Grade {
    /// 計算百分比（如果未設定則自動計算）
    var calculatedPercentage: Double? {
        if let percentage = percentage {
            return percentage
        }
        guard let score = score else { return nil }
        return (score / maxScore) * 100
    }
    
    /// 根據分數自動計算等級
    var calculatedGrade: LetterGrade? {
        guard let percentage = calculatedPercentage else { return nil }
        return LetterGrade.fromPercentage(percentage)
    }
    
    /// 顯示成績（優先顯示等級，其次分數）
    var displayGrade: String {
        if let grade = grade {
            return grade.rawValue
        }
        if let isPass = isPass {
            return isPass ? "通過" : "不通過"
        }
        if let score = score {
            return String(format: "%.1f / %.1f", score, maxScore)
        }
        return "未評分"
    }
    
    /// 成績顏色（用於 UI 顯示）
    var gradeColor: String {
        guard let percentage = calculatedPercentage else { return "#6B7280" }
        if percentage >= 90 { return "#10B981" }      // 綠色（優秀）
        if percentage >= 80 { return "#3B82F6" }      // 藍色（良好）
        if percentage >= 70 { return "#F59E0B" }      // 橙色（及格）
        if percentage >= 60 { return "#F97316" }      // 深橙（勉強及格）
        return "#EF4444"                              // 紅色（不及格）
    }
    
    /// 是否已評分
    var isGraded: Bool {
        return status == .graded && (score != nil || grade != nil || isPass != nil)
    }
    
    /// 是否已發布
    var canView: Bool {
        return isReleased || status == .graded
    }
}

// MARK: - Letter Grade (等級)

/// 字母等級
enum LetterGrade: String, Codable, CaseIterable {
    case A = "A"
    case APlus = "A+"
    case AMinus = "A-"
    case B = "B"
    case BPlus = "B+"
    case BMinus = "B-"
    case C = "C"
    case CPlus = "C+"
    case CMinus = "C-"
    case D = "D"
    case DPlus = "D+"
    case DMinus = "D-"
    case F = "F"
    
    var displayName: String {
        return rawValue
    }
    
    var numericValue: Double {
        switch self {
        case .APlus: return 97
        case .A: return 93
        case .AMinus: return 90
        case .BPlus: return 87
        case .B: return 83
        case .BMinus: return 80
        case .CPlus: return 77
        case .C: return 73
        case .CMinus: return 70
        case .DPlus: return 67
        case .D: return 63
        case .DMinus: return 60
        case .F: return 0
        }
    }
    
    /// 從百分比轉換為等級
    static func fromPercentage(_ percentage: Double) -> LetterGrade {
        switch percentage {
        case 97...100: return .APlus
        case 93..<97: return .A
        case 90..<93: return .AMinus
        case 87..<90: return .BPlus
        case 83..<87: return .B
        case 80..<83: return .BMinus
        case 77..<80: return .CPlus
        case 73..<77: return .C
        case 70..<73: return .CMinus
        case 67..<70: return .DPlus
        case 63..<67: return .D
        case 60..<63: return .DMinus
        default: return .F
        }
    }
}

// MARK: - Grade Status (成績狀態)

/// 成績狀態
enum GradeStatus: String, Codable, CaseIterable {
    case pending = "pending"         // 待評分
    case inProgress = "in_progress"   // 評分中
    case graded = "graded"           // 已評分
    case needsRevision = "needs_revision" // 需要修改
    case excused = "excused"         // 免修
    
    var displayName: String {
        switch self {
        case .pending: return "待評分"
        case .inProgress: return "評分中"
        case .graded: return "已評分"
        case .needsRevision: return "需要修改"
        case .excused: return "免修"
        }
    }
}

// MARK: - Rubric Score (評分標準細項)

/// 評分標準細項（用於詳細評分）
struct RubricScore: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var criterion: String            // 評分標準名稱
    var score: Double                // 得分
    var maxScore: Double             // 滿分
    var feedback: String?            // 該項的評語
    
    init(
        id: String = UUID().uuidString,
        criterion: String,
        score: Double,
        maxScore: Double,
        feedback: String? = nil
    ) {
        self.id = id
        self.criterion = criterion
        self.score = score
        self.maxScore = maxScore
        self.feedback = feedback
    }
}

// MARK: - Grade Item (成績項目)

/// 成績項目（用於計算總成績）
struct GradeItem: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var organizationId: String
    var name: String                 // 項目名稱（例如："作業1", "期中考"）
    var category: String?            // 分類（例如："作業", "測驗"）
    var weight: Double               // 權重（0-100，用於計算總成績）
    var maxScore: Double             // 滿分
    var dueDate: Date?               // 截止日期
    var isRequired: Bool             // 是否為必做項目
    var description: String?         // 項目描述
    
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case name
        case category
        case weight
        case maxScore
        case dueDate
        case isRequired
        case description
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        organizationId: String,
        name: String,
        category: String? = nil,
        weight: Double,
        maxScore: Double,
        dueDate: Date? = nil,
        isRequired: Bool = true,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.name = name
        self.category = category
        self.weight = weight
        self.maxScore = maxScore
        self.dueDate = dueDate
        self.isRequired = isRequired
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Grade Category (成績分類)

/// 成績分類（用於組織成績項目）
struct GradeCategory: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var organizationId: String
    var name: String                 // 分類名稱（例如："作業", "測驗", "專案"）
    var weight: Double               // 分類權重（0-100）
    var description: String?         // 分類描述
    
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case name
        case weight
        case description
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        organizationId: String,
        name: String,
        weight: Double,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.name = name
        self.weight = weight
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Grade Summary (成績摘要)

/// 成績摘要（用於顯示總成績）
struct GradeSummary: Codable, Identifiable {
    var id: String { userId }
    var userId: String
    var organizationId: String
    var finalScore: Double?          // 總分
    var finalPercentage: Double?      // 總百分比
    var finalGrade: LetterGrade?      // 總等級
    var gradeItems: [GradeItemSummary] // 各項成績摘要
    
    struct GradeItemSummary: Codable, Identifiable {
        var id: String
        var name: String
        var score: Double?
        var maxScore: Double
        var percentage: Double?
        var weight: Double
        var weightedScore: Double?    // 加權分數
    }
}

// MARK: - Grade Statistics (成績統計)

/// 成績統計（用於分析）
struct GradeStatistics: Codable {
    var organizationId: String
    var totalStudents: Int            // 總學生數
    var gradedCount: Int              // 已評分數
    var averageScore: Double?         // 平均分
    var medianScore: Double?          // 中位數
    var highestScore: Double?         // 最高分
    var lowestScore: Double?          // 最低分
    var passRate: Double?             // 通過率
    var distribution: [GradeDistribution] // 成績分布
    
    struct GradeDistribution: Codable {
        var grade: LetterGrade
        var count: Int
        var percentage: Double
    }
}

