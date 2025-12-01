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

    // Moodle-like features
    var fileName: String?                   // 原始檔案名稱
    var fileSize: Int64?                    // 檔案大小（bytes）
    var mimeType: String?                   // MIME 類型
    var version: Int = 1                    // 版本號
    var previousVersionId: String?          // 前一版本 ID
    var downloadCount: Int = 0              // 下載次數
    var isPublic: Bool = false              // 是否公開（不需登入即可下載）
    var accessibleRoleIds: [String]?        // 可存取的角色 ID 列表（權限控制）

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
        case fileName
        case fileSize
        case mimeType
        case version
        case previousVersionId
        case downloadCount
        case isPublic
        case accessibleRoleIds
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
        fileName: String? = nil,
        fileSize: Int64? = nil,
        mimeType: String? = nil,
        version: Int = 1,
        previousVersionId: String? = nil,
        downloadCount: Int = 0,
        isPublic: Bool = false,
        accessibleRoleIds: [String]? = nil,
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
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.version = version
        self.previousVersionId = previousVersionId
        self.downloadCount = downloadCount
        self.isPublic = isPublic
        self.accessibleRoleIds = accessibleRoleIds
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Helper Methods

    /// 格式化檔案大小
    var fileSizeFormatted: String {
        guard let size = fileSize else { return "未知" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 檢查用戶角色是否有權限存取
    func canAccess(userRoleIds: [String]) -> Bool {
        if isPublic { return true }
        guard let accessibleRoleIds = accessibleRoleIds else { return true } // 無限制
        return userRoleIds.contains(where: { accessibleRoleIds.contains($0) })
    }
}
