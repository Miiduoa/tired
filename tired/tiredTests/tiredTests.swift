//
//  tiredTests.swift
//  tiredTests
//
//  Created by Han demo on 2025/10/23.
//

import Testing
@testable import tired

struct tiredTests {
    @MainActor
    @Test func moduleOverridesApplyMetadata() async throws {
        let tenant = Tenant(
            id: "t-1",
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
        let membership = TenantMembership(
            id: tenant.id,
            tenant: tenant,
            role: .manager,
            capabilityPack: pack
        )
        let user = User(id: "unit-test", email: "unit@test.app", displayName: "測試成員", provider: "email")
        let session = AppSession(
            user: user,
            activeMembership: membership,
            allMemberships: [membership],
            personalProfile: PersonalProfile.default(for: user)
        )

        let manager = TenantModuleManager()
        let activitiesMeta = manager.metadata(for: .activities, membership: membership)
        #expect(activitiesMeta.title == "客製活動")
        #expect(activitiesMeta.systemImage == "sparkles")

        let actions = await manager.quickActions(for: [.activities], session: session) { _ in }
        #expect(actions.first?.title == "客製活動")
        #expect(actions.first?.icon == "sparkles")
    }
}
