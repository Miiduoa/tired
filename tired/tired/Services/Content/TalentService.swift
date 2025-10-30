import Foundation
import FirebaseFirestore

protocol TalentServiceProtocol {
    func fetchExperiences(for user: User) async -> [Experience]
    func updateExperience(_ experience: Experience, for user: User) async throws
    func submitApplication(to organizationId: String, post: Post, user: User) async throws
}

final class TalentService: TalentServiceProtocol {
    private let db = Firestore.firestore()
    private let cache = ExperienceCache.shared
    private let cacheMaxAge: TimeInterval = 60
    
    func fetchExperiences(for user: User) async -> [Experience] {
        if let cached = await cache.experiences(for: user.id, maxAge: cacheMaxAge) {
            return cached
        }
        let collection = db.collection("users").document(user.id)
            .collection("experiences")
            .order(by: "startDate", descending: true)
        do {
            let snapshot = try await collection.getDocuments()
            let experiences: [Experience] = snapshot.documents.compactMap { FirestoreExperienceMapper.experience(from: $0) }
            await cache.setExperiences(experiences, for: user.id)
            return experiences
        } catch {
            print("⚠️ 無法載入經歷資料：\(error.localizedDescription)")
            let fallback = [Experience.sampleEmployment(), Experience.sampleEducation()]
            await cache.setExperiences(fallback, for: user.id)
            return fallback
        }
    }
    
    func updateExperience(_ experience: Experience, for user: User) async throws {
        let data = FirestoreExperienceMapper.makeDictionary(from: experience)
        let document = db.collection("users").document(user.id)
            .collection("experiences").document(experience.id)
        try await document.setData(data, merge: false)
        await cache.invalidate(for: user.id)
    }
    
    func submitApplication(to organizationId: String, post: Post, user: User) async throws {
        var data: [String: Any] = [
            "organizationId": organizationId,
            "postId": post.id,
            "applicantId": user.id,
            "submittedAt": Timestamp(date: Date()),
            "summary": post.summary,
            "content": post.content,
            "visibility": post.visibility.rawValue,
            "category": post.category.rawValue
        ]
        if !user.displayName.isEmpty {
            data["displayName"] = user.displayName
        }
        if !user.email.isEmpty {
            data["email"] = user.email
        }
        if let phone = user.phoneNumber {
            data["phoneNumber"] = phone
        }
        let experienceIds = await fetchExperiences(for: user).map(\.id)
        if !experienceIds.isEmpty {
            data["experienceIds"] = experienceIds
        }
        
        let document = db.collection("applications").document()
        try await document.setData(data)
    }
}

// MARK: - Cache

actor ExperienceCache {
    static let shared = ExperienceCache()
    
    private struct CacheEntry {
        let experiences: [Experience]
        let timestamp: Date
        
        func isValid(maxAge: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) <= maxAge
        }
    }
    
    private var entries: [String: CacheEntry] = [:]
    
    private init() {}
    
    func experiences(for userId: String, maxAge: TimeInterval) -> [Experience]? {
        guard let entry = entries[userId], entry.isValid(maxAge: maxAge) else { return nil }
        return entry.experiences
    }
    
    func setExperiences(_ experiences: [Experience], for userId: String) {
        entries[userId] = CacheEntry(experiences: experiences, timestamp: Date())
    }
    
    func invalidate(for userId: String) {
        entries.removeValue(forKey: userId)
    }
}
