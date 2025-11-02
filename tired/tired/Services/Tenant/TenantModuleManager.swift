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
        // 預設值
        var meta: TenantModuleMetadata
        switch module {
        case .home:
            meta = TenantModuleMetadata(title: "首頁", systemImage: "house.fill", accentColor: .accentColor)
        case .broadcast:
            meta = TenantModuleMetadata(title: "公告", systemImage: "megaphone.fill", accentColor: .purple)
        case .inbox:
            meta = TenantModuleMetadata(title: "收件匣", systemImage: "tray.fill", accentColor: .blue)
        case .attendance:
            meta = TenantModuleMetadata(title: "出勤", systemImage: "person.badge.clock.fill", accentColor: .orange)
        case .clock:
            meta = TenantModuleMetadata(title: "打卡", systemImage: "location.fill", accentColor: .green)
        case .esg:
            meta = TenantModuleMetadata(title: "ESG", systemImage: "leaf.fill", accentColor: .mint)
        case .activities:
            meta = TenantModuleMetadata(title: "活動", systemImage: "calendar", accentColor: .pink)
        case .insights:
            meta = TenantModuleMetadata(title: "分析", systemImage: "chart.line.uptrend.xyaxis", accentColor: .indigo)
        case .feed:
            meta = TenantModuleMetadata(title: "動態", systemImage: "square.grid.2x2", accentColor: .cyan)
        case .chat:
            meta = TenantModuleMetadata(title: "訊息", systemImage: "message.fill", accentColor: .blue)
        case .friends:
            meta = TenantModuleMetadata(title: "好友", systemImage: "person.2.fill", accentColor: .teal)
        case .profile:
            meta = TenantModuleMetadata(title: "個人", systemImage: "person.crop.circle", accentColor: .gray)
        }

        // 套用租戶層級覆寫：
        // - module.<rawValue>.title / icon / color
        let keyPrefix = "module.\(module.rawValue)"
        if let title = membership.tenant.metadata["\(keyPrefix).title"], !title.isEmpty {
            meta = TenantModuleMetadata(title: title, systemImage: meta.systemImage, accentColor: meta.accentColor)
        }
        if let icon = membership.tenant.metadata["\(keyPrefix).icon"], !icon.isEmpty {
            meta = TenantModuleMetadata(title: meta.title, systemImage: icon, accentColor: meta.accentColor)
        }
        if let colorHex = membership.tenant.metadata["\(keyPrefix).color"], let color = parseColor(hex: colorHex) {
            meta = TenantModuleMetadata(title: meta.title, systemImage: meta.systemImage, accentColor: color)
        }
        return meta
    }

    private func parseColor(hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let hexStr = String(trimmed.dropFirst())
        var value: UInt64 = 0
        guard Scanner(string: hexStr).scanHexInt64(&value) else { return nil }
        switch hexStr.count {
        case 6: // RRGGBB
            let r = Double((value & 0xFF0000) >> 16) / 255.0
            let g = Double((value & 0x00FF00) >> 8) / 255.0
            let b = Double(value & 0x0000FF) / 255.0
            return Color(red: r, green: g, blue: b)
        case 8: // RRGGBBAA
            let r = Double((value & 0xFF000000) >> 24) / 255.0
            let g = Double((value & 0x00FF0000) >> 16) / 255.0
            let b = Double((value & 0x0000FF00) >> 8) / 255.0
            let a = Double(value & 0x000000FF) / 255.0
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        default:
            return nil
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
