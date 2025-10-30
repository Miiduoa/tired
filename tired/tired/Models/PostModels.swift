import Foundation

enum PostSourceType: String, Codable {
    case personal
    case organization
}

enum PostVisibility: String, Codable, CaseIterable, Identifiable {
    case `public`
    case connections
    case organizations
    case privateOnly
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .public: return "公開"
        case .connections: return "人脈可見"
        case .organizations: return "組織限定"
        case .privateOnly: return "僅自己"
        }
    }
}

enum PostCategory: String, Codable, CaseIterable, Identifiable {
    case announcement
    case job
    case project
    case learning
    case general
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .announcement: return "公告"
        case .job: return "職缺"
        case .project: return "專案"
        case .learning: return "學習"
        case .general: return "一般"
        }
    }
}

struct Post: Identifiable, Codable {
    let id: String
    let sourceType: PostSourceType
    let sourceId: String
    let authorName: String
    let authorAvatarURL: URL?
    let organizationName: String?
    let category: PostCategory
    let visibility: PostVisibility
    let summary: String
    let content: String
    let createdAt: Date
    let tags: [String]
    let metadata: [String: String]
    
    init(
        id: String,
        sourceType: PostSourceType,
        sourceId: String,
        authorName: String,
        authorAvatarURL: URL? = nil,
        organizationName: String? = nil,
        category: PostCategory,
        visibility: PostVisibility,
        summary: String,
        content: String,
        createdAt: Date,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.organizationName = organizationName
        self.category = category
        self.visibility = visibility
        self.summary = summary
        self.content = content
        self.createdAt = createdAt
        self.tags = tags
        self.metadata = metadata
    }
}

extension Post {
    static func samplePersonal(authorId: String = "user-1") -> Post {
        Post(
            id: UUID().uuidString,
            sourceType: .personal,
            sourceId: authorId,
            authorName: "Pine",
            category: .project,
            visibility: .public,
            summary: "完成 AI 課程期末專案",
            content: "這週完成了 AI 課程期末專案，包含模型訓練與 UI Demo，歡迎指教！",
            createdAt: Date().addingTimeInterval(-3600),
            tags: ["AI", "課程"]
        )
    }
    
    static func sampleOrganization(orgId: String = "org-demo") -> Post {
        Post(
            id: UUID().uuidString,
            sourceType: .organization,
            sourceId: orgId,
            authorName: "北城大學資管系",
            organizationName: "北城大學資管系",
            category: .job,
            visibility: .public,
            summary: "誠徵助教 - AI 課程",
            content: "課程需要一位助教，熟悉 SwiftUI 與 Firebase 優先，內部同學可優先應徵。",
            createdAt: Date().addingTimeInterval(-7200),
            tags: ["助教", "AI"]
        )
    }
    
    var attachmentURLs: [URL] {
        guard let raw = metadata["attachments.json"], let data = raw.data(using: .utf8) else { return [] }
        let strings = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return strings.compactMap { URL(string: $0) }
    }
}
