import Foundation

struct PersonalProfile: Codable {
    var headline: String
    var summary: String
    var experiences: [Experience]
    var skills: [String]
    var isOpenToWork: Bool
    var preferredLocations: [String]
    var preferredRoles: [String]
    var tags: [String]
    
    static func `default`(for user: User) -> PersonalProfile {
        PersonalProfile(
            headline: "你好，\(user.displayName.isEmpty ? "tired 使用者" : user.displayName)!",
            summary: "分享你的作品、經歷，讓組織更認識你。",
            experiences: [Experience.sampleEmployment(), Experience.sampleEducation()],
            skills: ["Swift", "UI Design", "Firebase"],
            isOpenToWork: true,
            preferredLocations: ["台北", "遠端"],
            preferredRoles: ["iOS Developer", "產品設計"],
            tags: ["AI", "ESG", "校園社群"]
        )
    }
}
