import Foundation
import FirebaseFirestore

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
