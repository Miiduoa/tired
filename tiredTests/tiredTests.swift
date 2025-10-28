//
//  tiredTests.swift
//  tiredTests
//
//  Created by Han demo on 2025/10/23.
//

import Testing
@testable import tired

struct tiredTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @MainActor
    @Test func moduleOverridesApplyMetadata() throws {
        let tenant = Tenant(
            name: "測試企業",
            type: .company,
            metadata: [
                "module.activities.title": "客製活動",
                "module.activities.icon": "sparkles",
                "module.activities.color": "#FF9500",
                "module.insights.title": "出勤雷達",
                "module.insights.icon": "gauge.high"
            ]
        )
        let pack = CapabilityPack(
            id: "test-pack",
            name: "Test Pack",
            enabledModules: [.home, .activities, .insights, .profile]
        )
        let membership = TenantMembership(tenant: tenant, role: .manager, capabilityPack: pack)
        let user = User(id: "unit-test", email: "unit@test.app", displayName: "測試成員", provider: "email")
        let session = AppSession(user: user, activeMembership: membership, allMemberships: [membership])
        
        let testCenter = ModuleConfigurationCenter(definitionsByTenantType: [:])
        let manager = TenantModuleManager(configurationCenter: testCenter)
        manager.configure(for: session)
        
        let activitiesMeta = manager.metadata(for: .activities)
        #expect(activitiesMeta?.title == "客製活動")
        #expect(activitiesMeta?.systemImage == "sparkles")
        
        let actions = manager.entryActions(for: [.activities], session: session) { _ in }
        #expect(actions.first?.title == "客製活動")
        #expect(actions.first?.icon == "sparkles")
    }

}
