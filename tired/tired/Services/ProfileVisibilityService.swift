import Foundation
import FirebaseFirestore
import Combine

/// 個人資料可見度控制服務
@MainActor
final class ProfileVisibilityService: ObservableObject {
    static let shared = ProfileVisibilityService()
    
    @Published var profileFields: [ProfileField] = []
    @Published var audienceLists: [AudienceList] = []
    @Published var shareTokens: [ShareToken] = []
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Profile Fields Management
    
    /// 獲取用戶的所有資料欄位
    func fetchProfileFields(userId: String) async throws -> [ProfileField] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("profile_fields")
            .getDocuments()
        
        let fields = snapshot.documents.compactMap { doc -> ProfileField? in
            try? doc.data(as: ProfileField.self)
        }
        
        await MainActor.run {
            self.profileFields = fields
        }
        
        return fields
    }
    
    /// 更新欄位資料和可見度
    func updateProfileField(userId: String, field: ProfileField) async throws {
        try db.collection("users").document(userId)
            .collection("profile_fields")
            .document(field.id)
            .setData(from: field, merge: true)
        
        // 更新本地
        if let index = profileFields.firstIndex(where: { $0.id == field.id }) {
            profileFields[index] = field
        }
    }
    
    /// 批量更新欄位
    func updateProfileFields(userId: String, fields: [ProfileField]) async throws {
        let batch = db.batch()
        
        for field in fields {
            let ref = db.collection("users").document(userId)
                .collection("profile_fields")
                .document(field.id)
            try batch.setData(from: field, forDocument: ref, merge: true)
        }
        
        try await batch.commit()
        
        // 更新本地
        for field in fields {
            if let index = profileFields.firstIndex(where: { $0.id == field.id }) {
                profileFields[index] = field
            }
        }
    }
    
    // MARK: - Visibility Check
    
    /// 檢查欄位是否對觀察者可見
    func isVisible(
        field: ProfileField,
        viewer: String,
        ownerGroups: [String],
        viewerGroups: [String],
        ownerOrgs: [String],
        viewerOrgs: [String],
        friendIds: [String]
    ) -> Bool {
        let visibility = field.visibility
        
        switch visibility.mode {
        case .public:
            return true
            
        case .private:
            return false
            
        case .friends:
            return friendIds.contains(viewer)
            
        case .group:
            if let groups = visibility.groups {
                return !Set(groups).intersection(Set(viewerGroups)).isEmpty
            }
            return false
            
        case .org:
            if let orgs = visibility.orgs {
                return !Set(orgs).intersection(Set(viewerOrgs)).isEmpty
            }
            return false
            
        case .custom:
            if let listIds = visibility.listIds {
                // 檢查觀察者是否在自訂清單中
                return audienceLists.contains { list in
                    listIds.contains(list.id) && list.members.contains(viewer)
                }
            }
            return false
        }
    }
    
    /// 獲取對觀察者可見的資料
    func getVisibleProfile(
        userId: String,
        viewerId: String,
        viewerGroupIds: [String],
        viewerOrgIds: [String],
        friendIds: [String],
        groupId: String? = nil
    ) async throws -> VisibleProfile {
        let fields = try await fetchProfileFields(userId: userId)
        let lists = try await fetchAudienceLists(userId: userId)
        
        await MainActor.run {
            self.audienceLists = lists
        }
        
        var visibleFields: [ProfileField] = []
        
        for field in fields {
            // 檢查是否有群組特定覆蓋
            var effectiveField = field
            if let groupId = groupId, let scoped = field.scoped, let override = scoped[groupId] {
                // 應用群組覆蓋
                if let overrideValue = override["value"] as? String {
                    effectiveField.value = .string(overrideValue)
                }
                // TODO: 應用其他覆蓋屬性
            }
            
            // 檢查可見度
            let isVisible = isVisible(
                field: effectiveField,
                viewer: viewerId,
                ownerGroups: viewerGroupIds,
                viewerGroups: viewerGroupIds,
                ownerOrgs: viewerOrgIds,
                viewerOrgs: viewerOrgIds,
                friendIds: friendIds
            )
            
            if isVisible {
                visibleFields.append(effectiveField)
            }
        }
        
        return VisibleProfile(
            userId: userId,
            fields: visibleFields
        )
    }
    
    // MARK: - Audience Lists
    
    /// 獲取自訂觀眾清單
    func fetchAudienceLists(userId: String) async throws -> [AudienceList] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("audience_lists")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> AudienceList? in
            try? doc.data(as: AudienceList.self)
        }
    }
    
    /// 創建觀眾清單
    func createAudienceList(userId: String, name: String, members: [String]) async throws -> AudienceList {
        let list = AudienceList(
            id: UUID().uuidString,
            name: name,
            members: members,
            smartRule: nil
        )
        
        try db.collection("users").document(userId)
            .collection("audience_lists")
            .document(list.id)
            .setData(from: list)
        
        audienceLists.append(list)
        
        return list
    }
    
    /// 更新觀眾清單
    func updateAudienceList(userId: String, list: AudienceList) async throws {
        try db.collection("users").document(userId)
            .collection("audience_lists")
            .document(list.id)
            .setData(from: list, merge: true)
        
        if let index = audienceLists.firstIndex(where: { $0.id == list.id }) {
            audienceLists[index] = list
        }
    }
    
    /// 刪除觀眾清單
    func deleteAudienceList(userId: String, listId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("audience_lists")
            .document(listId)
            .delete()
        
        audienceLists.removeAll { $0.id == listId }
    }
    
    // MARK: - Temporary Share
    
    /// 創建臨時分享連結
    func createShareToken(
        ownerId: String,
        fieldIds: [String],
        scope: ShareScope,
        expiresAt: Date
    ) async throws -> ShareToken {
        let token = ShareToken(
            id: UUID().uuidString,
            ownerUid: ownerId,
            fields: fieldIds,
            scope: scope,
            expiresAt: expiresAt,
            createdAt: Date(),
            revoked: false
        )
        
        try db.collection("profile_shares")
            .document(token.id)
            .setData(from: token)
        
        shareTokens.append(token)
        
        return token
    }
    
    /// 撤銷分享
    func revokeShareToken(tokenId: String) async throws {
        try await db.collection("profile_shares")
            .document(tokenId)
            .updateData(["revoked": true])
        
        if let index = shareTokens.firstIndex(where: { $0.id == tokenId }) {
            shareTokens[index].revoked = true
        }
    }
    
    /// 驗證並獲取分享內容
    func getSharedProfile(token: String, viewerId: String) async throws -> VisibleProfile? {
        let doc = try await db.collection("profile_shares")
            .document(token)
            .getDocument()
        
        guard let shareToken = try? doc.data(as: ShareToken.self) else {
            throw ProfileVisibilityError.invalidToken
        }
        
        // 檢查是否已撤銷
        if shareToken.revoked {
            throw ProfileVisibilityError.tokenRevoked
        }
        
        // 檢查是否過期
        if shareToken.expiresAt < Date() {
            throw ProfileVisibilityError.tokenExpired
        }
        
        // 檢查觀察者是否在範圍內
        if !isViewerInScope(viewerId: viewerId, scope: shareToken.scope) {
            throw ProfileVisibilityError.accessDenied
        }
        
        // 獲取指定欄位
        let allFields = try await fetchProfileFields(userId: shareToken.ownerUid)
        let sharedFields = allFields.filter { shareToken.fields.contains($0.id) }
        
        return VisibleProfile(
            userId: shareToken.ownerUid,
            fields: sharedFields
        )
    }
    
    /// 獲取用戶的所有分享 token
    func fetchShareTokens(userId: String) async throws -> [ShareToken] {
        let snapshot = try await db.collection("profile_shares")
            .whereField("ownerUid", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> ShareToken? in
            try? doc.data(as: ShareToken.self)
        }
    }
    
    // MARK: - Access Audit
    
    /// 記錄存取
    func logAccess(viewerId: String, ownerId: String, fieldIds: [String]) async {
        let log = AccessLog(
            viewerId: viewerId,
            ownerId: ownerId,
            fieldIds: fieldIds,
            timestamp: Date()
        )
        
        // 存儲到 Firestore（聚合存取記錄）
        _ = try? db.collection("users").document(ownerId)
            .collection("access_logs")
            .addDocument(data: [
                "viewerId": viewerId,
                "fieldIds": fieldIds,
                "timestamp": Timestamp(date: Date())
            ])
    }
    
    /// 獲取存取記錄（聚合版本）
    func fetchAccessSummary(userId: String, days: Int = 30) async throws -> [AccessSummary] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("users").document(userId)
            .collection("access_logs")
            .whereField("timestamp", isGreaterThan: Timestamp(date: startDate))
            .getDocuments()
        
        // 聚合統計
        var summary: [String: Int] = [:]
        
        for doc in snapshot.documents {
            if let viewerId = doc.data()["viewerId"] as? String {
                summary[viewerId, default: 0] += 1
            }
        }
        
        return summary.map { viewerId, count in
            AccessSummary(viewerId: viewerId, accessCount: count)
        }.sorted { $0.accessCount > $1.accessCount }
    }
    
    // MARK: - Helper Methods
    
    private func isViewerInScope(viewerId: String, scope: ShareScope) -> Bool {
        if let uids = scope.uids, !uids.isEmpty {
            return uids.contains(viewerId)
        }
        
        // TODO: 檢查 groups 和 listIds
        
        return false
    }
}

// MARK: - Models

struct ProfileField: Identifiable, Codable {
    var id: String
    let key: String // displayName, bio, link1, tags, studentId, avatar
    let type: FieldType
    var value: FieldValue
    var visibility: Visibility
    var scoped: [String: [String: Any]]? // groupId -> overrides
    var updatedAt: Date
    var version: Int
    
    enum FieldType: String, Codable {
        case text, link, tags, image
    }
    
    enum FieldValue: Codable {
        case string(String)
        case array([String])
        case url(String)
        
        enum CodingKeys: CodingKey {
            case type, value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "string":
                let value = try container.decode(String.self, forKey: .value)
                self = .string(value)
            case "array":
                let value = try container.decode([String].self, forKey: .value)
                self = .array(value)
            case "url":
                let value = try container.decode(String.self, forKey: .value)
                self = .url(value)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .string(let value):
                try container.encode("string", forKey: .type)
                try container.encode(value, forKey: .value)
            case .array(let value):
                try container.encode("array", forKey: .type)
                try container.encode(value, forKey: .value)
            case .url(let value):
                try container.encode("url", forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }
    }
}

struct Visibility: Codable {
    var mode: VisibilityMode
    var groups: [String]?
    var orgs: [String]?
    var listIds: [String]?
    var expiresAt: Date?
    
    enum VisibilityMode: String, Codable {
        case `public`, friends, group, org, `private`, custom
    }
}

struct AudienceList: Identifiable, Codable {
    let id: String
    var name: String
    var members: [String]
    var smartRule: SmartRule?
}

struct SmartRule: Codable {
    let type: String // "sameGroup", "sameOrg", "role"
    let args: [String: String]
}

struct ShareToken: Codable {
    let id: String
    let ownerUid: String
    let fields: [String]
    let scope: ShareScope
    let expiresAt: Date
    let createdAt: Date
    var revoked: Bool
}

struct ShareScope: Codable {
    var uids: [String]?
    var groups: [String]?
    var listIds: [String]?
}

struct VisibleProfile {
    let userId: String
    let fields: [ProfileField]
}

struct AccessLog {
    let viewerId: String
    let ownerId: String
    let fieldIds: [String]
    let timestamp: Date
}

struct AccessSummary {
    let viewerId: String
    let accessCount: Int
}

enum ProfileVisibilityError: LocalizedError {
    case invalidToken
    case tokenRevoked
    case tokenExpired
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "無效的分享連結"
        case .tokenRevoked:
            return "分享連結已被撤銷"
        case .tokenExpired:
            return "分享連結已過期"
        case .accessDenied:
            return "無權訪問"
        }
    }
}

