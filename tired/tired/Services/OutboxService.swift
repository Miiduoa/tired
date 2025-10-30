import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
import SwiftUI
import Combine

// A simple, resilient outbox to persist user actions and retry later.
// Current scope: broadcast ACK events.
@MainActor
final class OutboxService: ObservableObject {
    static let shared = OutboxService()

    private struct Storage: Codable {
        var itemsByUser: [String: [OutboxItem]]
    }

    struct OutboxItem: Codable, Identifiable, Hashable {
        enum Kind: String, Codable { case broadcastAck, inboxAck, clockRecord, attendanceCheck, attendanceSessionOpen, attendanceSessionClose }
        let id: String
        let kind: Kind
        let uid: String
        let broadcastId: String?
        let membershipId: String?
        let inboxItemId: String?
        let siteId: String?
        let sessId: String?
        let timestamp: Date?
        let courseId: String?
        let closeAt: Date?
        let idempotencyKey: String
        let createdAt: Date

        static func broadcastAck(broadcastId: String, uid: String, idempotencyKey: String) -> OutboxItem {
            OutboxItem(
                id: "outbox-ack-\(broadcastId)-\(idempotencyKey)",
                kind: .broadcastAck,
                uid: uid,
                broadcastId: broadcastId,
                membershipId: nil,
                inboxItemId: nil,
                siteId: nil,
                sessId: nil,
                timestamp: Date(),
                courseId: nil,
                closeAt: nil,
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
        }

        static func inboxAck(inboxItemId: String, membershipId: String, uid: String) -> OutboxItem {
            OutboxItem(
                id: "outbox-inboxAck-\(membershipId)-\(inboxItemId)",
                kind: .inboxAck,
                uid: uid,
                broadcastId: nil,
                membershipId: membershipId,
                inboxItemId: inboxItemId,
                siteId: nil,
                sessId: nil,
                timestamp: Date(),
                courseId: nil,
                closeAt: nil,
                idempotencyKey: "",
                createdAt: Date()
            )
        }

        static func clockRecord(siteId: String, uid: String, idempotencyKey: String, ts: Date) -> OutboxItem {
            OutboxItem(
                id: "outbox-clock-\(siteId)-\(idempotencyKey)",
                kind: .clockRecord,
                uid: uid,
                broadcastId: nil,
                membershipId: nil,
                inboxItemId: nil,
                siteId: siteId,
                sessId: nil,
                timestamp: ts,
                courseId: nil,
                closeAt: nil,
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
        }

        static func attendanceCheck(sessId: String, uid: String, idempotencyKey: String, ts: Date) -> OutboxItem {
            OutboxItem(
                id: "outbox-att-\(sessId)-\(idempotencyKey)",
                kind: .attendanceCheck,
                uid: uid,
                broadcastId: nil,
                membershipId: nil,
                inboxItemId: nil,
                siteId: nil,
                sessId: sessId,
                timestamp: ts,
                courseId: nil,
                closeAt: nil,
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
        }

        static func attendanceSessionOpen(membershipId: String, courseId: String, openAt: Date, closeAt: Date, policyId: String) -> OutboxItem {
            OutboxItem(
                id: "outbox-att-open-\(membershipId)-\(courseId)-\(Int(openAt.timeIntervalSince1970))",
                kind: .attendanceSessionOpen,
                uid: "", // not needed
                broadcastId: nil,
                membershipId: membershipId,
                inboxItemId: nil,
                siteId: nil,
                sessId: nil,
                timestamp: openAt,
                courseId: courseId,
                closeAt: closeAt,
                idempotencyKey: policyId,
                createdAt: Date()
            )
        }

        static func attendanceSessionClose(sessId: String) -> OutboxItem {
            OutboxItem(
                id: "outbox-att-close-\(sessId)",
                kind: .attendanceSessionClose,
                uid: "",
                broadcastId: nil,
                membershipId: nil,
                inboxItemId: nil,
                siteId: nil,
                sessId: sessId,
                timestamp: nil,
                courseId: nil,
                closeAt: nil,
                idempotencyKey: "",
                createdAt: Date()
            )
        }
    }

    private let storageKey = "Outbox.byUser.v1"
    private var itemsByUser: [String: [OutboxItem]] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Storage.self, from: data) {
            itemsByUser = decoded.itemsByUser
        }
    }

    private var currentUserKey: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? "anonymous"
        #else
        return "anonymous"
        #endif
    }

    func enqueueBroadcastAck(broadcastId: String, uid: String, idempotencyKey: String) {
        var items = itemsByUser[uid] ?? []
        let item = OutboxItem.broadcastAck(broadcastId: broadcastId, uid: uid, idempotencyKey: idempotencyKey)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[uid] = items
            persist()
        }
    }

    func enqueueInboxAck(inboxItemId: String, membershipId: String) {
        let uid = currentUserKey
        var items = itemsByUser[uid] ?? []
        let item = OutboxItem.inboxAck(inboxItemId: inboxItemId, membershipId: membershipId, uid: uid)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[uid] = items
            persist()
        }
    }

    func enqueueClockRecord(siteId: String, uid: String, idempotencyKey: String, ts: Date) {
        var items = itemsByUser[uid] ?? []
        let item = OutboxItem.clockRecord(siteId: siteId, uid: uid, idempotencyKey: idempotencyKey, ts: ts)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[uid] = items
            persist()
        }
    }

    func enqueueAttendanceCheck(sessId: String, uid: String, idempotencyKey: String, ts: Date) {
        var items = itemsByUser[uid] ?? []
        let item = OutboxItem.attendanceCheck(sessId: sessId, uid: uid, idempotencyKey: idempotencyKey, ts: ts)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[uid] = items
            persist()
        }
    }

    func enqueueAttendanceSessionOpen(membershipId: String, courseId: String, openAt: Date, closeAt: Date, policyId: String = "default") {
        var items = itemsByUser[currentUserKey] ?? []
        let item = OutboxItem.attendanceSessionOpen(membershipId: membershipId, courseId: courseId, openAt: openAt, closeAt: closeAt, policyId: policyId)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[currentUserKey] = items
            persist()
        }
    }

    func enqueueAttendanceSessionClose(sessId: String) {
        var items = itemsByUser[currentUserKey] ?? []
        let item = OutboxItem.attendanceSessionClose(sessId: sessId)
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            itemsByUser[currentUserKey] = items
            persist()
        }
    }

    func flush(for uid: String? = nil) async {
        let key = uid ?? currentUserKey
        guard var queue = itemsByUser[key], !queue.isEmpty else { return }

        var remaining: [OutboxItem] = []
        for item in queue {
            switch item.kind {
            case .broadcastAck:
                if let bid = item.broadcastId {
                    do {
                        try await BroadcastAPI.ack(broadcastId: bid, uid: item.uid, idempotencyKey: item.idempotencyKey)
                        // success: drop
                    } catch {
                        // keep for retry
                        remaining.append(item)
                    }
                } else {
                    // malformed, drop it
                }
            case .clockRecord, .attendanceCheck:
                // require session context or dedicated API; leave for flush(session:)
                remaining.append(item)
            case .inboxAck:
                // needs membership context; skip here and rely on flush(session:) to handle
                remaining.append(item)
            case .attendanceSessionOpen, .attendanceSessionClose:
                // handled in flush(session:)
                remaining.append(item)
            }
        }
        itemsByUser[key] = remaining
        persist()
    }

    func flush(session: AppSession) async {
        let uid = currentUserKey
        guard var queue = itemsByUser[uid], !queue.isEmpty else { return }

        var remaining: [OutboxItem] = []
        let service = TenantFeatureService()

        for item in queue {
            switch item.kind {
            case .broadcastAck:
                if let bid = item.broadcastId {
                    do {
                        try await BroadcastAPI.ack(broadcastId: bid, uid: item.uid, idempotencyKey: item.idempotencyKey)
                    } catch {
                        remaining.append(item)
                    }
                }
            case .inboxAck:
                guard let mid = item.membershipId, let iid = item.inboxItemId,
                      let membership = session.allMemberships.first(where: { $0.id == mid }) else {
                    // unresolved membership or malformed: drop
                    continue
                }
                // Build minimal InboxItem; integration uses id only for ack
                let dummy = InboxItem(
                    id: iid,
                    kind: .ack,
                    title: "",
                    subtitle: "",
                    deadline: nil,
                    isUrgent: false,
                    priority: .normal,
                    eventId: nil
                )
                do {
                    try await service.acknowledgeInboxItem(dummy, membership: membership)
                } catch {
                    remaining.append(item)
                }
            case .clockRecord:
                if let siteId = item.siteId, let ts = item.timestamp {
                    do {
                        _ = try await ClockAPI.submit(siteId: siteId, uid: item.uid, idempotencyKey: item.idempotencyKey, ts: ts)
                    } catch {
                        remaining.append(item)
                    }
                }
            case .attendanceCheck:
                if let sessId = item.sessId, let ts = item.timestamp {
                    do {
                        _ = try await AttendanceAPI.submitCheck(sessId: sessId, uid: item.uid, idempotencyKey: item.idempotencyKey, ts: ts)
                    } catch {
                        remaining.append(item)
                    }
                }
            case .attendanceSessionOpen:
                if let openAt = item.timestamp, let closeAt = item.closeAt, let courseId = item.courseId {
                    do {
                        _ = try await AttendanceAPI.createSession(courseId: courseId, policyId: item.idempotencyKey, openAt: openAt, closeAt: closeAt)
                    } catch {
                        remaining.append(item)
                    }
                }
            case .attendanceSessionClose:
                if let sessId = item.sessId {
                    do { try await AttendanceAPI.closeSession(sessId: sessId) }
                    catch { remaining.append(item) }
                }
            }
        }
        itemsByUser[uid] = remaining
        persist()
    }

    private func persist() {
        let payload = Storage(itemsByUser: itemsByUser)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func remove(id: String, for uid: String? = nil) {
        let key = uid ?? currentUserKey
        guard var items = itemsByUser[key] else { return }
        items.removeAll { $0.id == id }
        itemsByUser[key] = items
        persist()
    }
}
