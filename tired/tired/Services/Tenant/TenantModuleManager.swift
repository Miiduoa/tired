import SwiftUI
import Combine

@MainActor
final class TenantModuleManager: ObservableObject {
    private let featureService: TenantFeatureServiceProtocol
    
    init(featureService: TenantFeatureServiceProtocol) {
        self.featureService = featureService
    }
    
    convenience init() {
        self.init(featureService: TenantFeatureService())
    }
    
    func availableModules(for membership: TenantMembership) -> [AppModule] {
        var modules: [AppModule] = [.home]
        let baseEnabled = membership.capabilityPack.enabledModules
        let overrideEnabled = membership.enabledModulesOverride ?? baseEnabled
        let configEnabled = membership.configuration?.featureFlags.enabledModules ?? overrideEnabled
        let effective = overrideEnabled.intersection(configEnabled)
        modules.append(contentsOf: effective.sorted { $0.rawValue < $1.rawValue })
        if !modules.contains(.profile) {
            modules.append(.profile)
        }
        return Array(NSOrderedSet(array: modules)) as? [AppModule] ?? modules
    }
    
    func metadata(for module: AppModule, membership: TenantMembership) -> TenantModuleMetadata {
        switch module {
        case .home:
            return TenantModuleMetadata(title: "首頁", systemImage: "house.fill", accentColor: .accentColor)
        case .broadcast:
            return TenantModuleMetadata(title: "公告", systemImage: "megaphone.fill", accentColor: .purple)
        case .inbox:
            return TenantModuleMetadata(title: "收件匣", systemImage: "tray.fill", accentColor: .blue)
        case .attendance:
            return TenantModuleMetadata(title: "出勤", systemImage: "person.badge.clock.fill", accentColor: .orange)
        case .clock:
            return TenantModuleMetadata(title: "打卡", systemImage: "location.fill", accentColor: .green)
        case .esg:
            return TenantModuleMetadata(title: "ESG", systemImage: "leaf.fill", accentColor: .mint)
        case .activities:
            return TenantModuleMetadata(title: "活動", systemImage: "calendar", accentColor: .pink)
        case .insights:
            return TenantModuleMetadata(title: "分析", systemImage: "chart.line.uptrend.xyaxis", accentColor: .indigo)
        case .feed:
            return TenantModuleMetadata(title: "動態", systemImage: "square.grid.2x2", accentColor: .cyan)
        case .chat:
            return TenantModuleMetadata(title: "訊息", systemImage: "message.fill", accentColor: .blue)
        case .friends:
            return TenantModuleMetadata(title: "好友", systemImage: "person.2.fill", accentColor: .teal)
        case .profile:
            return TenantModuleMetadata(title: "個人", systemImage: "person.crop.circle", accentColor: .gray)
        }
    }
    
    func quickActions(for modules: [AppModule], session: AppSession, select: @escaping (AppModule) -> Void) async -> [TenantModuleEntryAction] {
        var actions: [TenantModuleEntryAction] = []
        guard let membership = session.activeMembership else { return actions }
        let needsBroadcastData = modules.contains(.broadcast)
        let needsInboxData = modules.contains(.inbox)
        
        let broadcastTask = needsBroadcastData ? Task { await featureService.broadcasts(for: membership) } : nil
        let inboxTask = needsInboxData ? Task { await featureService.inboxItems(for: membership) } : nil
        
        let broadcastItems = await broadcastTask?.value ?? []
        let inboxItems = await inboxTask?.value ?? []
        
        for module in modules where module != .home {
            let meta = metadata(for: module, membership: membership)
            let badge: String?
            switch module {
            case .broadcast:
                let pending = broadcastItems.filter { $0.requiresAck && !AckStore.shared.isAcked($0.id) }.count
                badge = pending > 0 ? "\(pending)" : nil
            case .inbox:
                let urgent = inboxItems.filter { $0.isUrgent }.count
                badge = urgent > 0 ? "\(urgent)" : (inboxItems.isEmpty ? nil : "\(inboxItems.count)")
            default:
                badge = nil
            }
            actions.append(
                TenantModuleEntryAction(
                    module: module,
                    title: meta.title,
                    icon: meta.systemImage,
                    color: meta.accentColor,
                    badge: badge,
                    action: { select(module) }
                )
            )
        }
        return actions.sorted { ($0.badge ?? "0") > ($1.badge ?? "0") }
    }
}
