import Foundation
import Combine

@MainActor
final class PersonalTimelineStore: ObservableObject {
    @Published private(set) var posts: [Post] = []
    private let service: PersonalTimelineServiceProtocol
    private let user: User
    
    init(user: User, service: PersonalTimelineServiceProtocol = PersonalTimelineService()) {
        self.user = user
        self.service = service
    }
    
    func load() async {
        posts = await service.fetchPersonalPosts(for: user)
    }
    
    func create(summary: String, content: String, category: PostCategory, visibility: PostVisibility, attachments: [URL]) async throws {
        var metadata: [String: String] = [:]
        if !attachments.isEmpty,
           let data = try? JSONEncoder().encode(attachments.map { $0.absoluteString }),
           let jsonString = String(data: data, encoding: .utf8) {
            metadata["attachments.json"] = jsonString
        }
        let post = Post(
            id: UUID().uuidString,
            sourceType: .personal,
            sourceId: user.id,
            authorName: user.displayName.isEmpty ? (user.email.isEmpty ? "新用戶" : user.email) : user.displayName,
            category: category,
            visibility: visibility,
            summary: summary,
            content: content,
            createdAt: Date(),
            tags: [],
            metadata: metadata
        )
        try await service.createPost(post, for: user)
        posts.insert(post, at: 0)
    }
}
