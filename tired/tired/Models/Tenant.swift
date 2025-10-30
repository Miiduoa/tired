import Foundation

/// 支援的租戶類型，決定預設能力包與模組配置
enum TenantType: String, Codable, CaseIterable, Identifiable {
    case school
    case company
    case community
    case esg
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .school: return "校園"
        case .company: return "企業"
        case .community: return "社群"
        case .esg: return "SME-ESG"
        }
    }
}

/// App 中可用的功能模組，對應 Tab 與能力包
enum AppModule: String, Codable, CaseIterable, Identifiable {
    case home
    case broadcast
    case inbox
    case attendance
    case clock
    case esg
    case activities
    case insights
    case feed
    case chat
    case friends
    case profile
    
    var id: String { rawValue }
    
    var defaultTitle: String {
        switch self {
        case .home: return "首頁"
        case .broadcast: return "公告"
        case .inbox: return "收件匣"
        case .attendance: return "出勤"
        case .clock: return "打卡"
        case .esg: return "ESG"
        case .activities: return "活動"
        case .insights: return "分析"
        case .feed: return "動態"
        case .chat: return "訊息"
        case .friends: return "好友"
        case .profile: return "個人"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .home: return "house.fill"
        case .broadcast: return "megaphone.fill"
        case .inbox: return "tray.fill"
        case .attendance: return "person.badge.clock.fill"
        case .clock: return "location.fill"
        case .esg: return "leaf.fill"
        case .activities: return "calendar"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .feed: return "square.grid.2x2"
        case .chat: return "message.fill"
        case .friends: return "person.2.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

struct CapabilityPack: Codable, Identifiable {
    let id: String
    let name: String
    let enabledModules: Set<AppModule>
    
    init(id: String, name: String, enabledModules: Set<AppModule>) {
        self.id = id
        self.name = name
        self.enabledModules = enabledModules
    }
    
    static func defaultPack(for type: TenantType) -> CapabilityPack {
        switch type {
        case .school:
            return CapabilityPack(
                id: "pack-school",
                name: "Campus Pack",
                enabledModules: [.home, .broadcast, .attendance, .inbox, .activities, .feed, .chat, .friends, .insights, .profile]
            )
        case .company:
            return CapabilityPack(
                id: "pack-company",
                name: "Company Pack",
                enabledModules: [.home, .broadcast, .clock, .inbox, .activities, .feed, .chat, .friends, .insights, .profile]
            )
        case .community:
            return CapabilityPack(
                id: "pack-community",
                name: "Community Pack",
                enabledModules: [.home, .broadcast, .activities, .feed, .chat, .friends, .profile]
            )
        case .esg:
            return CapabilityPack(
                id: "pack-esg",
                name: "ESG Pack",
                enabledModules: [.home, .broadcast, .esg, .inbox, .insights, .profile]
            )
        }
    }
}

struct Tenant: Identifiable, Codable {
    let id: String
    let name: String
    let type: TenantType
    let logoURL: URL?
    let metadata: [String: String]
    
    init(id: String, name: String, type: TenantType, logoURL: URL? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.type = type
        self.logoURL = logoURL
        self.metadata = metadata
    }
}

struct TenantMembership: Identifiable, Codable {
    enum Role: String, Codable, CaseIterable {
        case owner
        case admin
        case manager
        case member
        case guest
        
        var displayName: String {
            switch self {
            case .owner: return "擁有者"
            case .admin: return "管理員"
            case .manager: return "經理"
            case .member: return "成員"
            case .guest: return "訪客"
            }
        }
        
        var isManagerial: Bool {
            switch self {
            case .owner, .admin, .manager: return true
            case .member, .guest: return false
            }
        }
    }
    
    let id: String
    let tenant: Tenant
    let role: Role
    let capabilityPack: CapabilityPack
    let enabledModulesOverride: Set<AppModule>?
    let configuration: TenantConfiguration?
    let metadata: [String: String]
    
    init(id: String, tenant: Tenant, role: Role, capabilityPack: CapabilityPack, enabledModulesOverride: Set<AppModule>? = nil, configuration: TenantConfiguration? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.tenant = tenant
        self.role = role
        self.capabilityPack = capabilityPack
        self.enabledModulesOverride = enabledModulesOverride
        self.configuration = configuration
        self.metadata = metadata
    }
    
    func hasAccess(to module: AppModule) -> Bool {
        if let override = enabledModulesOverride {
            return override.contains(module)
        }
        return capabilityPack.enabledModules.contains(module)
    }
}

struct AppSession: Identifiable, Codable {
    let id: UUID
    let user: User
    var activeMembership: TenantMembership?
    var allMemberships: [TenantMembership]
    var personalProfile: PersonalProfile
    var lastActiveModule: AppModule?
    
    init(
        id: UUID = UUID(),
        user: User,
        activeMembership: TenantMembership?,
        allMemberships: [TenantMembership],
        personalProfile: PersonalProfile,
        lastActiveModule: AppModule? = nil
    ) {
        self.id = id
        self.user = user
        self.activeMembership = activeMembership
        self.allMemberships = allMemberships
        self.personalProfile = personalProfile
        self.lastActiveModule = lastActiveModule
    }
    
    var isPersonalOnly: Bool { activeMembership == nil }
}
