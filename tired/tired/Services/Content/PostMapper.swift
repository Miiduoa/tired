import Foundation
import FirebaseFirestore

enum FirestorePostMapper {
    static func makeDictionary(from post: Post, tenantId: String? = nil) -> [String: Any] {
        var metadata = post.metadata
        metadata["sourceType"] = post.sourceType.rawValue
        metadata["sourceId"] = post.sourceId
        metadata["category"] = post.category.rawValue
        metadata["visibility"] = post.visibility.rawValue
        metadata["summary"] = post.summary
        metadata["content"] = post.content
        if let tenantId {
            metadata["tenantId"] = tenantId
        }
        var payload: [String: Any] = [
            "id": post.id,
            "sourceType": post.sourceType.rawValue,
            "sourceId": post.sourceId,
            "authorName": post.authorName,
            "summary": post.summary,
            "content": post.content,
            "createdAt": Timestamp(date: post.createdAt),
            "tags": post.tags,
            "metadata": metadata,
            "category": post.category.rawValue,
            "visibility": post.visibility.rawValue
        ]
        if let avatar = post.authorAvatarURL?.absoluteString {
            payload["authorAvatarURL"] = avatar
        }
        if let organizationName = post.organizationName {
            payload["organizationName"] = organizationName
        }
        if let targetOrg = post.metadata["targetOrgId"], !targetOrg.isEmpty {
            payload["targetOrgId"] = targetOrg
        }
        if let tenantId {
            payload["tenantId"] = tenantId
        }
        return payload
    }
    
    static func post(from document: DocumentSnapshot) -> Post? {
        let data = document.data() ?? [:]
        guard
            let sourceTypeRaw = data["sourceType"] as? String,
            let sourceType = PostSourceType(rawValue: sourceTypeRaw),
            let sourceId = data["sourceId"] as? String,
            let summary = data["summary"] as? String,
            let content = data["content"] as? String
        else { return nil }
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let timeInterval = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            createdAt = Date()
        }
        let metadata = data["metadata"] as? [String: String] ?? [:]
        let authorName = (data["authorName"] as? String).flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } ?? metadata["authorName"] ?? "匿名"
        let authorAvatarURL = (data["authorAvatarURL"] as? String) ?? metadata["authorAvatarURL"]
        let organizationName = (data["organizationName"] as? String) ?? metadata["organizationName"]
        let category = (data["category"] as? String).flatMap(PostCategory.init(rawValue:)) ?? PostCategory(rawValue: metadata["category"] ?? "") ?? .general
        let visibility = (data["visibility"] as? String).flatMap(PostVisibility.init(rawValue:)) ?? PostVisibility(rawValue: metadata["visibility"] ?? "") ?? .public
        let tags = data["tags"] as? [String] ?? []
        var composedMetadata = metadata
        if let topLevelMetadata = data["metadata"] as? [String: String] {
            composedMetadata.merge(topLevelMetadata) { current, _ in current }
        }
        if let tenantId = data["tenantId"] as? String {
            composedMetadata["tenantId"] = tenantId
        }
        if let target = data["targetOrgId"] as? String {
            composedMetadata["targetOrgId"] = target
        }
        if composedMetadata["targetOrgId"] == nil, let target = metadata["targetOrgId"] {
            composedMetadata["targetOrgId"] = target
        }
        return Post(
            id: document.documentID,
            sourceType: sourceType,
            sourceId: sourceId,
            authorName: authorName,
            authorAvatarURL: authorAvatarURL.flatMap { URL(string: $0) },
            organizationName: organizationName,
            category: category,
            visibility: visibility,
            summary: summary,
            content: content,
            createdAt: createdAt,
            tags: tags,
            metadata: composedMetadata
        )
    }
}

enum FirestoreExperienceMapper {
    static func makeDictionary(from experience: Experience) -> [String: Any] {
        var metadata = experience.metadata
        metadata["kind"] = experience.kind.rawValue
        metadata["organizationName"] = experience.organizationName
        metadata["role"] = experience.role
        metadata["summary"] = experience.summary
        metadata["visibility"] = experience.visibility.rawValue
        metadata["verification"] = experience.verification.rawValue
        var payload: [String: Any] = [
            "id": experience.id,
            "kind": experience.kind.rawValue,
            "organizationName": experience.organizationName,
            "role": experience.role,
            "startDate": Timestamp(date: experience.startDate),
            "summary": experience.summary,
            "attachments": experience.attachments.map { $0.absoluteString },
            "visibility": experience.visibility.rawValue,
            "verification": experience.verification.rawValue,
            "metadata": metadata
        ]
        if let organizationId = experience.organizationId {
            payload["organizationId"] = organizationId
        }
        if let endDate = experience.endDate {
            payload["endDate"] = Timestamp(date: endDate)
        }
        return payload
    }
    
    static func experience(from document: DocumentSnapshot) -> Experience? {
        let data = document.data() ?? [:]
        let metadata = data["metadata"] as? [String: String] ?? [:]
        let kind = Experience.Kind(rawValue: (data["kind"] as? String) ?? metadata["kind"] ?? "") ?? .employment
        let organizationName = (data["organizationName"] as? String) ?? metadata["organizationName"] ?? "未命名組織"
        let role = (data["role"] as? String) ?? metadata["role"] ?? "成員"
        let startDate: Date
        if let timestamp = data["startDate"] as? Timestamp {
            startDate = timestamp.dateValue()
        } else {
            startDate = Date()
        }
        var endDate: Date?
        if let timestamp = data["endDate"] as? Timestamp {
            endDate = timestamp.dateValue()
        }
        if endDate == nil, let iso = metadata["endDate"], let parsed = ISO8601DateFormatter().date(from: iso) {
            endDate = parsed
        }
        let attachments = (data["attachments"] as? [String] ?? []).compactMap { URL(string: $0) }
        let visibility = Experience.Visibility(rawValue: (data["visibility"] as? String) ?? metadata["visibility"] ?? "") ?? .public
        let verification = Experience.VerificationStatus(rawValue: (data["verification"] as? String) ?? metadata["verification"] ?? "") ?? .pending
        return Experience(
            id: document.documentID,
            kind: kind,
            organizationId: (data["organizationId"] as? String) ?? metadata["organizationId"],
            organizationName: organizationName,
            role: role,
            startDate: startDate,
            endDate: endDate,
            summary: (data["summary"] as? String) ?? metadata["summary"] ?? "",
            attachments: attachments,
            visibility: visibility,
            verification: verification,
            metadata: metadata
        )
    }
}
