import Foundation

struct Experience: Identifiable, Codable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case employment
        case education
        case project
        case certification
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .employment: return "工作經驗"
            case .education: return "學歷"
            case .project: return "專案"
            case .certification: return "證照"
            }
        }
    }
    
    enum VerificationStatus: String, Codable {
        case pending
        case verified
        case rejected
    }
    
    enum Visibility: String, Codable {
        case `public`
        case organizations
        case connections
        case privateOnly
    }
    
    let id: String
    var kind: Kind
    var organizationId: String?
    var organizationName: String
    var role: String
    var startDate: Date
    var endDate: Date?
    var summary: String
    var attachments: [URL]
    var visibility: Visibility
    var verification: VerificationStatus
    var metadata: [String: String]
    
    init(
        id: String = UUID().uuidString,
        kind: Kind,
        organizationId: String? = nil,
        organizationName: String,
        role: String,
        startDate: Date,
        endDate: Date? = nil,
        summary: String,
        attachments: [URL] = [],
        visibility: Visibility = .public,
        verification: VerificationStatus = .pending,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.role = role
        self.startDate = startDate
        self.endDate = endDate
        self.summary = summary
        self.attachments = attachments
        self.visibility = visibility
        self.verification = verification
        self.metadata = metadata
    }
}

extension Experience {
    static func sampleEmployment() -> Experience {
        Experience(
            kind: .employment,
            organizationId: "tsmc",
            organizationName: "TSMC",
            role: "軟體工程師",
            startDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
            summary: "負責內部生產系統的資料可視化平台，導入 SwiftUI 與 Firebase。",
            visibility: .organizations,
            verification: .verified
        )
    }
    
    static func sampleEducation() -> Experience {
        Experience(
            kind: .education,
            organizationId: "ncu",
            organizationName: "靜宜大學",
            role: "資管系學生",
            startDate: Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date(),
            endDate: nil,
            summary: "主修資訊管理，專注於 AI 應用與 UX 設計。",
            visibility: .public,
            verification: .pending
        )
    }
}
