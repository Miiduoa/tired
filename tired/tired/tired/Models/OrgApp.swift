import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - OrgAppInstance

struct OrgAppInstance: Codable, Identifiable {
    @DocumentID var id: String?
    var organizationId: String
    var templateKey: OrgAppTemplateKey

    var name: String?
    var config: [String: String]?

    var isEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case templateKey
        case name
        case config
        case isEnabled
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        organizationId: String,
        templateKey: OrgAppTemplateKey,
        name: String? = nil,
        config: [String: String]? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.templateKey = templateKey
        self.name = name
        self.config = config
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Resource

/// 資源類型
enum ResourceType: String, Codable, CaseIterable {
    case document = "document"
    case link = "link"
    case file = "file"
    case image = "image"
    case video = "video"

    var displayName: String {
        switch self {
        case .document: return "文件"
        case .link: return "連結"
        case .file: return "檔案"
        case .image: return "圖片"
        case .video: return "影片"
        }
    }

    var iconName: String {
        switch self {
        case .document: return "doc.text"
        case .link: return "link"
        case .file: return "folder"
        case .image: return "photo"
        case .video: return "play.rectangle"
        }
    }
}

/// 組織資源
struct Resource: Codable, Identifiable {
    @DocumentID var id: String?
    var orgAppInstanceId: String
    var organizationId: String

    var title: String
    var description: String?
    var type: ResourceType
    var url: String?
    var fileUrl: String?

    var category: String?
    var tags: [String]?

    var createdByUserId: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orgAppInstanceId
        case organizationId
        case title
        case description
        case type
        case url
        case fileUrl
        case category
        case tags
        case createdByUserId
        case createdAt
        case updatedAt
    }

    init(
        id: String? = nil,
        orgAppInstanceId: String,
        organizationId: String,
        title: String,
        description: String? = nil,
        type: ResourceType,
        url: String? = nil,
        fileUrl: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        createdByUserId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orgAppInstanceId = orgAppInstanceId
        self.organizationId = organizationId
        self.title = title
        self.description = description
        self.type = type
        self.url = url
        self.fileUrl = fileUrl
        self.category = category
        self.tags = tags
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
