import Foundation

// MARK: - Local models

struct AttendanceSessionRecord: Codable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable { case open, closed }
    let id: String
    let membershipId: String
    let courseId: String
    let teacherId: String
    let openAt: Date
    var closeAt: Date
    var qrSeed: String
    var status: Status
}

struct AttendanceCheckRecord: Codable, Identifiable, Sendable {
    let id: String
    let sessionId: String
    let membershipId: String
    let userId: String
    let timestamp: Date
}

// MARK: - Local store

actor AttendanceLocalStore {
    private struct Persisted: Codable {
        var sessions: [String: AttendanceSessionRecord]
        var checksBySession: [String: [AttendanceCheckRecord]]
    }

    private let storageKey = "AttendanceLocalStore.v1"
    private var sessions: [String: AttendanceSessionRecord] = [:]
    private var checksBySession: [String: [AttendanceCheckRecord]] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            sessions = decoded.sessions
            checksBySession = decoded.checksBySession
        }
    }

    func upsert(session: AttendanceSessionRecord) {
        sessions[session.id] = session
        persist()
    }

    func markClosed(sessionId: String, closedAt: Date) {
        guard var session = sessions[sessionId] else { return }
        session.status = .closed
        session.closeAt = closedAt
        sessions[sessionId] = session
        persist()
    }

    func add(check: AttendanceCheckRecord) {
        var list = checksBySession[check.sessionId] ?? []
        list.append(check)
        list.sort { $0.timestamp > $1.timestamp }
        checksBySession[check.sessionId] = list
        persist()
    }

    func session(id: String) -> AttendanceSessionRecord? {
        sessions[id]
    }

    func latestSession(for membershipId: String) -> AttendanceSessionRecord? {
        sessions.values
            .filter { $0.membershipId == membershipId }
            .sorted { $0.openAt > $1.openAt }
            .first
    }

    func checks(for sessionId: String, userId: String? = nil) -> [AttendanceCheckRecord] {
        guard let list = checksBySession[sessionId] else { return [] }
        guard let userId else { return list }
        return list.filter { $0.userId == userId }
    }

    private func persist() {
        let payload = Persisted(sessions: sessions, checksBySession: checksBySession)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Attendance service

@MainActor
final class AttendanceService {
    static let shared = AttendanceService()

    private let localStore = AttendanceLocalStore()

    struct OpenSessionResult {
        let record: AttendanceSessionRecord
        let ttlSeconds: Int
    }

    private init() {}

    func openSession(
        membership: TenantMembership,
        courseId: String,
        teacherId: String,
        durationMinutes: Int
    ) async -> OpenSessionResult {
        let openAt = Date()
        let validDuration = max(1, durationMinutes) * 60
        let closeAt = openAt.addingTimeInterval(TimeInterval(validDuration))

        do {
            let response = try await AttendanceAPI.openSession(
                courseId: courseId,
                teacherId: teacherId,
                validDuration: validDuration
            )
            let record = AttendanceSessionRecord(
                id: response.sessionId,
                membershipId: membership.id,
                courseId: courseId,
                teacherId: teacherId,
                openAt: openAt,
                closeAt: closeAt,
                qrSeed: response.qrSeed,
                status: .open
            )
            await localStore.upsert(session: record)
            return OpenSessionResult(record: record, ttlSeconds: validDuration)
        } catch {
            let localId = "local-\(UUID().uuidString)"
            let record = AttendanceSessionRecord(
                id: localId,
                membershipId: membership.id,
                courseId: courseId,
                teacherId: teacherId,
                openAt: openAt,
                closeAt: closeAt,
                qrSeed: localId,
                status: .open
            )
            await localStore.upsert(session: record)
            OutboxService.shared.enqueueAttendanceSessionOpen(
                membershipId: membership.id,
                courseId: courseId,
                openAt: openAt,
                closeAt: closeAt
            )
            return OpenSessionResult(record: record, ttlSeconds: validDuration)
        }
    }

    func closeSession(sessionId: String, membershipId: String, teacherId: String) async {
        let closedAt = Date()
        do {
            try await AttendanceAPI.closeSession(sessionId: sessionId, teacherId: teacherId)
        } catch {
            OutboxService.shared.enqueueAttendanceSessionClose(sessId: sessionId)
        }
        await localStore.markClosed(sessionId: sessionId, closedAt: closedAt)
    }

    func checkIn(
        sessionId: String,
        membershipId: String,
        userId: String,
        courseName: String
    ) async -> AttendanceRecord {
        let timestamp = Date()
        if userId != "guest" && !userId.isEmpty {
            do {
                try await AttendanceAPI.checkIn(userId: userId, sessionId: sessionId)
            } catch {
                let key = "att-\(UUID().uuidString)"
                OutboxService.shared.enqueueAttendanceCheck(
                    sessId: sessionId,
                    uid: userId,
                    idempotencyKey: key,
                    ts: timestamp
                )
            }
        }

        let check = AttendanceCheckRecord(
            id: "local-check-\(UUID().uuidString)",
            sessionId: sessionId,
            membershipId: membershipId,
            userId: userId,
            timestamp: timestamp
        )
        await localStore.add(check: check)

        return AttendanceRecord(
            courseName: courseName,
            date: timestamp,
            status: .present
        )
    }

    func mergedSnapshot(
        base: AttendanceSnapshot,
        membership: TenantMembership,
        userId: String?
    ) async -> AttendanceSnapshot {
        guard let userId else { return base }
        let currentSession = base
        let checks = await sessionChecks(for: membership, userId: userId)
        guard !checks.isEmpty else { return base }

        // Append unique records by timestamp
        var personal = currentSession.personalRecords
        let existingDates = Set(personal.map { $0.date })
        for record in checks {
            if !existingDates.contains(record.date) {
                personal.insert(record, at: 0)
            }
        }

        return AttendanceSnapshot(
            courseName: currentSession.courseName,
            attendanceTime: currentSession.attendanceTime,
            validDuration: currentSession.validDuration,
            stats: currentSession.stats,
            personalRecords: personal.sorted { $0.date > $1.date }
        )
    }

    func localFallbackSnapshot(
        membership: TenantMembership,
        userId: String?
    ) async -> AttendanceSnapshot? {
        guard let session = await localStore.latestSession(for: membership.id) else { return nil }
        let checks = await sessionChecks(for: membership, userId: userId)
        let stats = AttendanceStats(
            attended: checks.count,
            absent: 0,
            late: 0,
            total: max(1, checks.count)
        )
        return AttendanceSnapshot(
            courseName: membership.tenant.name,
            attendanceTime: session.openAt,
            validDuration: Int(session.closeAt.timeIntervalSince(session.openAt) / 60),
            stats: stats,
            personalRecords: checks
        )
    }

    private func sessionChecks(
        for membership: TenantMembership,
        userId: String?
    ) async -> [AttendanceRecord] {
        guard let session = await localStore.latestSession(for: membership.id) else { return [] }
        let checks = await localStore.checks(for: session.id, userId: userId)
        return checks.map { AttendanceRecord(courseName: membership.tenant.name, date: $0.timestamp, status: .present) }
    }
}
