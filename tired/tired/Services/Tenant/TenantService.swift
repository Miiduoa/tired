import Foundation
import FirebaseFirestore

protocol TenantServiceProtocol {
    func fetchMemberships(for user: User) async throws -> [TenantMembership]
}

final class TenantService: TenantServiceProtocol {
    private let db = Firestore.firestore()
    
    func fetchMemberships(for user: User) async throws -> [TenantMembership] {
        let snapshot = try await db.collection("members")
            .whereField("uid", isEqualTo: user.id)
            .getDocuments()
        
        if snapshot.documents.isEmpty {
            return TenantContentProvider.demoMemberships(for: user)
        }
        
        var memberships: [TenantMembership] = []
        for doc in snapshot.documents {
            let data = try doc.data(as: FirestoreMember.self)
            let tenantType = TenantType(rawValue: data.tenantType ?? "community") ?? .community
            let tenantName = data.tenantName ?? "未命名組織"
            let capabilityPack: CapabilityPack
            if let packId = data.capabilityPack,
               let pack = TenantContentProvider.packByIdentifier(packId, fallbackType: tenantType) {
                capabilityPack = pack
            } else {
                capabilityPack = CapabilityPack.defaultPack(for: tenantType)
            }
            let tenant = Tenant(
                id: data.groupId,
                name: tenantName,
                type: tenantType,
                logoURL: data.logoURL.flatMap(URL.init(string:)),
                metadata: data.metadata ?? [:]
            )
            let role = TenantMembership.Role(rawValue: data.role ?? "member") ?? .member
            let overrides: Set<AppModule>? = {
                guard let rawModules = data.enabledModules else { return nil }
                let modules = rawModules.compactMap(AppModule.init(rawValue:))
                return modules.isEmpty ? nil : Set(modules)
            }()
            let configuration: TenantConfiguration?
            if let configID = data.integrationConfig,
               let adapter = TenantConfiguration.AdapterType(rawValue: data.integrationAdapter ?? "") {
                if let baseURLString = data.integrationBaseURL,
                   let url = URL(string: baseURLString) {
                    let restConfig = TenantConfiguration.RESTConfiguration(
                        baseURL: url,
                        authMethod: TenantConfiguration.RESTConfiguration.AuthMethod(rawValue: data.integrationAuthMethod ?? "none") ?? .none,
                        headers: data.integrationHeaders ?? [:],
                        queries: data.integrationQueries ?? [:],
                        credentials: data.integrationCredentials ?? [:]
                    )
                    configuration = TenantConfiguration(
                        id: configID,
                        adapter: adapter,
                        rest: restConfig,
                        featureFlags: TenantConfiguration.FeatureFlags(enabledModules: capabilityPack.enabledModules),
                        options: data.integrationOptions ?? [:]
                    )
                } else {
                    configuration = TenantConfiguration(
                        id: configID,
                        adapter: adapter,
                        featureFlags: TenantConfiguration.FeatureFlags(enabledModules: capabilityPack.enabledModules),
                        options: data.integrationOptions ?? [:]
                    )
                }
            } else {
                configuration = nil
            }
            memberships.append(
                TenantMembership(
                    id: data.groupId,
                    tenant: tenant,
                    role: role,
                    capabilityPack: capabilityPack,
                    enabledModulesOverride: overrides,
                    configuration: configuration,
                    metadata: data.metadata ?? [:]
                )
            )
        }
        
        return memberships.sorted { $0.tenant.name.localizedCaseInsensitiveCompare($1.tenant.name) == .orderedAscending }
    }
}

fileprivate struct FirestoreMember: Codable {
    let uid: String
    let groupId: String
    let orgId: String?
    let role: String?
    let capabilityPack: String?
    let tenantType: String?
    let tenantName: String?
    let logoURL: String?
    let metadata: [String: String]?
    let enabledModules: [String]?
    let integrationConfig: String?
    let integrationAdapter: String?
    let integrationBaseURL: String?
    let integrationAuthMethod: String?
    let integrationHeaders: [String: String]?
    let integrationQueries: [String: String]?
    let integrationCredentials: [String: String]?
    let integrationOptions: [String: String]?
}
