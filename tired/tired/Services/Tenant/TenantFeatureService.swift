
import Foundation
import FirebaseFirestore

protocol TenantFeatureServiceProtocol {
    func broadcasts(for membership: TenantMembership) async -> [BroadcastListItem]
    func inboxItems(for membership: TenantMembership) async -> [InboxItem]
    func activities(for membership: TenantMembership) async -> [ActivityListItem]
    func clockRecords(for membership: TenantMembership) async -> [ClockRecordItem]
    func attendanceSnapshot(for membership: TenantMembership) async -> AttendanceSnapshot
    func esgSummary(for membership: TenantMembership) async -> ESGSummary
    func insights(for membership: TenantMembership) async -> [InsightSection]
    func acknowledgeInboxItem(_ item: InboxItem, membership: TenantMembership) async throws
}

/// 優化後的租戶功能服務，包含緩存和錯誤處理
final class TenantFeatureService: TenantFeatureServiceProtocol {
    // MARK: - 緩存管理
    
    private struct CacheEntry<T> {
        let data: T
        let timestamp: Date
        let membershipId: String
        
        func isValid(for membershipId: String, maxAge: TimeInterval) -> Bool {
            self.membershipId == membershipId && Date().timeIntervalSince(timestamp) < maxAge
        }
    }
    
    private var cache: [String: Any] = [:]
    private let cacheMaxAge: TimeInterval = 30 // 30秒緩存
    
    // MARK: - Integration Factory
    
    private func integration(for membership: TenantMembership) -> TenantIntegrationProtocol {
        let context = TenantIntegrationContext(
            tenant: membership.tenant,
            membership: membership,
            configuration: membership.configuration
        )
        return TenantIntegrationFactory.makeIntegration(for: context)
    }
    
    // MARK: - 通用獲取邏輯（帶緩存和降級）
    
    private func fetchWithCache<T>(
        cacheKey: String,
        membership: TenantMembership,
        fetch: @escaping () async throws -> T,
        fallback: @escaping (TenantMembership) -> T
    ) async -> T {
        // 檢查緩存
        if let cached = cache[cacheKey] as? CacheEntry<T>,
           cached.isValid(for: membership.id, maxAge: cacheMaxAge) {
            return cached.data
        }
        
        // 從服務獲取
        do {
            let data = try await fetch()
            
            // 更新緩存
            cache[cacheKey] = CacheEntry(data: data, timestamp: Date(), membershipId: membership.id)
            
            // 如果數據為空，使用後備數據
            if let list = data as? any Collection, list.isEmpty {
                return fallback(membership)
            }
            
            return data
        } catch {
            print("⚠️ 獲取 \(cacheKey) 失敗：\(error.localizedDescription)，使用後備數據")
            
            // 如果有緩存的舊數據，使用它
            if let cached = cache[cacheKey] as? CacheEntry<T>,
               cached.membershipId == membership.id {
                return cached.data
            }
            
            // 否則使用後備數據
            return fallback(membership)
        }
    }
    
    // MARK: - 具體實現
    
    func broadcasts(for membership: TenantMembership) async -> [BroadcastListItem] {
        await fetchWithCache(
            cacheKey: "broadcasts_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchBroadcasts() },
            fallback: TenantContentProvider.broadcasts(for:)
        )
    }
    
    func inboxItems(for membership: TenantMembership) async -> [InboxItem] {
        await fetchWithCache(
            cacheKey: "inbox_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchInboxItems() },
            fallback: TenantContentProvider.inbox(for:)
        )
    }
    
    func activities(for membership: TenantMembership) async -> [ActivityListItem] {
        await fetchWithCache(
            cacheKey: "activities_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchActivities() },
            fallback: TenantContentProvider.activities(for:)
        )
    }
    
    func clockRecords(for membership: TenantMembership) async -> [ClockRecordItem] {
        await fetchWithCache(
            cacheKey: "clock_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchClockRecords() },
            fallback: TenantContentProvider.clockRecords(for:)
        )
    }
    
    func attendanceSnapshot(for membership: TenantMembership) async -> AttendanceSnapshot {
        await fetchWithCache(
            cacheKey: "attendance_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchAttendanceSnapshot() },
            fallback: TenantContentProvider.attendanceSnapshot(for:)
        )
    }
    
    func esgSummary(for membership: TenantMembership) async -> ESGSummary {
        await fetchWithCache(
            cacheKey: "esg_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchESGSummary() },
            fallback: TenantContentProvider.esgSummary(for:)
        )
    }
    
    func insights(for membership: TenantMembership) async -> [InsightSection] {
        await fetchWithCache(
            cacheKey: "insights_\(membership.id)",
            membership: membership,
            fetch: { [self] in try await self.integration(for: membership).fetchInsights() },
            fallback: TenantContentProvider.insights(for:)
        )
    }
    
    func acknowledgeInboxItem(_ item: InboxItem, membership: TenantMembership) async throws {
        // 確認操作立即清除相關緩存
        cache.removeValue(forKey: "inbox_\(membership.id)")
        cache.removeValue(forKey: "activities_\(membership.id)")
        
        try await integration(for: membership).acknowledgeInboxItem(item)
    }
    
    // MARK: - 緩存管理
    
    func clearCache(for membershipId: String? = nil) {
        if let id = membershipId {
            // 清除特定租戶的緩存
            cache = cache.filter { key, _ in !key.hasSuffix("_\(id)") }
        } else {
            // 清除所有緩存
            cache.removeAll()
        }
    }
}
