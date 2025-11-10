import Foundation

actor ClockLocalStore {
    private let storageKey = "ClockLocalStore.records.v1"
    private var recordsByMembership: [String: [ClockRecordItem]] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [ClockRecordItem]].self, from: data) {
            recordsByMembership = decoded
        }
    }

    func add(record: ClockRecordItem, membershipId: String) {
        var list = recordsByMembership[membershipId] ?? []
        list.append(record)
        list.sort { $0.time > $1.time }
        recordsByMembership[membershipId] = list
        persist()
    }

    func records(for membershipId: String) -> [ClockRecordItem] {
        recordsByMembership[membershipId] ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(recordsByMembership) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class ClockService {
    static let shared = ClockService()

    private let localStore = ClockLocalStore()

    private init() {}

    func records(
        for membership: TenantMembership,
        remoteService: TenantFeatureServiceProtocol
    ) async -> [ClockRecordItem] {
        let remote = await remoteService.clockRecords(for: membership)
        let local = await localStore.records(for: membership.id)
        let remoteIds = Set(remote.map(\.id))
        let merged = remote + local.filter { !remoteIds.contains($0.id) }
        var unique: [String: ClockRecordItem] = [:]
        for record in merged {
            let key = record.dedupeKey
            if let existing = unique[key] {
                if record.time > existing.time {
                    unique[key] = record
                }
            } else {
                unique[key] = record
            }
        }
        return unique.values.sorted { $0.time > $1.time }
    }

    func recordClock(
        for membership: TenantMembership,
        siteName: String,
        userId: String?
    ) async -> ClockRecordItem {
        let timestamp = Date()
        let record = ClockRecordItem(
            id: "local-clock-\(UUID().uuidString)",
            site: siteName,
            time: timestamp,
            status: .ok
        )
        await localStore.add(record: record, membershipId: membership.id)

        guard let userId, !userId.isEmpty else {
            return record
        }

        let key = "clock-\(UUID().uuidString)"
        OutboxService.shared.enqueueClockRecord(
            siteId: membership.id,
            uid: userId,
            idempotencyKey: key,
            ts: timestamp
        )

        do {
            _ = try await ClockAPI.clockIn(
                uid: userId,
                site: membership.id,
                idempotencyKey: key,
                timestamp: timestamp
            )
            OutboxService.shared.remove(id: "outbox-clock-\(membership.id)-\(key)", for: userId)
        } catch {
            // 留給 outbox 重試
        }

        return record
    }
}
