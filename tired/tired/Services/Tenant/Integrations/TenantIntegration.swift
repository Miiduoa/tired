import Foundation
import Combine

/// 每個租戶需提供的整合上下文基礎資訊。
struct TenantIntegrationContext: Sendable {
    let tenant: Tenant
    let membership: TenantMembership
    let configuration: TenantConfiguration?
}

/// 針對不同來源系統撰寫的 Adapter 必須實作的介面。
protocol TenantIntegrationProtocol: Sendable {
    func fetchBroadcasts() async throws -> [BroadcastListItem]
    func fetchInboxItems() async throws -> [InboxItem]
    func fetchActivities() async throws -> [ActivityListItem]
    func fetchClockRecords() async throws -> [ClockRecordItem]
    func fetchAttendanceSnapshot() async throws -> AttendanceSnapshot
    func fetchESGSummary() async throws -> ESGSummary
    func fetchInsights() async throws -> [InsightSection]
    func acknowledgeInboxItem(_ item: InboxItem) async throws
}

extension TenantIntegrationProtocol {
    func fetchBroadcasts() async throws -> [BroadcastListItem] { [] }
    func fetchInboxItems() async throws -> [InboxItem] { [] }
    func fetchActivities() async throws -> [ActivityListItem] { [] }
    func fetchClockRecords() async throws -> [ClockRecordItem] { [] }
    func fetchAttendanceSnapshot() async throws -> AttendanceSnapshot {
        guard let membership = TenantContentProvider.demoMemberships(for: .demoUser()).first else {
            throw TenantIntegrationError.missingConfiguration("demo membership not available")
        }
        return TenantContentProvider.attendanceSnapshot(for: membership)
    }
    func fetchESGSummary() async throws -> ESGSummary {
        guard let membership = TenantContentProvider.demoMemberships(for: .demoUser()).first else {
            throw TenantIntegrationError.missingConfiguration("demo membership not available")
        }
        return TenantContentProvider.esgSummary(for: membership)
    }
    func fetchInsights() async throws -> [InsightSection] { [] }
    func acknowledgeInboxItem(_ item: InboxItem) async throws {}
}

enum TenantIntegrationError: Error {
    case unsupportedAdapter(String)
    case missingConfiguration(String)
}

private extension User {
    static func demoUser() -> User {
        User(
            id: "demo-user",
            email: "demo@tired.team",
            displayName: "Demo User",
            photoURL: nil,
            provider: "local",
            phoneNumber: nil,
            isEmailVerified: true,
            isPhoneVerified: false,
            createdAt: Date(),
            lastLoginAt: Date(),
            preferences: UserPreferences()
        )
    }
}
