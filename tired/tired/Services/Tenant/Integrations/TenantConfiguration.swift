import Foundation
import Combine

/// 描述租戶與外部系統整合所需的設定。
struct TenantConfiguration: Codable, Sendable {
    enum AdapterType: String, Codable {
        case firebase
        case rest
        case graphQL
        case custom
    }
    
    let id: String
    let adapter: AdapterType
    let rest: RESTConfiguration?
    let featureFlags: FeatureFlags
    let options: [String: String]
    
    init(
        id: String,
        adapter: AdapterType,
        rest: RESTConfiguration? = nil,
        featureFlags: FeatureFlags = .defaultFlags(),
        options: [String: String] = [:]
    ) {
        self.id = id
        self.adapter = adapter
        self.rest = rest
        self.featureFlags = featureFlags
        self.options = options
    }
}

extension TenantConfiguration {
    struct RESTConfiguration: Codable, Sendable {
        enum AuthMethod: String, Codable {
            case none
            case apiKey
            case bearerToken
            case basic
        }
        
        let baseURL: URL
        let authMethod: AuthMethod
        let headers: [String: String]
        let queries: [String: String]
        let credentials: [String: String]
        
        init(
            baseURL: URL,
            authMethod: AuthMethod = .none,
            headers: [String: String] = [:],
            queries: [String: String] = [:],
            credentials: [String: String] = [:]
        ) {
            self.baseURL = baseURL
            self.authMethod = authMethod
            self.headers = headers
            self.queries = queries
            self.credentials = credentials
        }
    }
    
    struct FeatureFlags: Codable, Sendable {
        var enabledModules: Set<AppModule>
        var extra: [String: Bool]
        
        init(enabledModules: Set<AppModule>, extra: [String: Bool] = [:]) {
            self.enabledModules = enabledModules
            self.extra = extra
        }
        
        static func defaultFlags() -> FeatureFlags {
            FeatureFlags(enabledModules: Set(AppModule.allCases))
        }
    }
}
