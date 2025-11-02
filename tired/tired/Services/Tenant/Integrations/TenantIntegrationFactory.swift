import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// 建立對應租戶的整合 Adapter。
enum TenantIntegrationFactory {
    static func makeIntegration(for context: TenantIntegrationContext) -> TenantIntegrationProtocol {
        guard let configuration = context.configuration else {
            return FirebaseTenantIntegration(context: context)
        }
        
        switch configuration.adapter {
        case .firebase:
            return FirebaseTenantIntegration(context: context)
        case .rest:
            return RESTTenantIntegration(context: context, configuration: configuration)
        case .graphQL:
            return GraphQLTenantIntegration(context: context, configuration: configuration)
        case .custom:
            return FirebaseTenantIntegration(context: context)
        }
    }
}

/// 預設採用現有 Firestore 行為。
final class FirebaseTenantIntegration: TenantIntegrationProtocol {
    private let membership: TenantMembership
    private let db = Firestore.firestore()
    private let ackStore = AckStore.shared
    
    init(context: TenantIntegrationContext) {
        self.membership = context.membership
    }
    
    func fetchBroadcasts() async throws -> [BroadcastListItem] {
        let collection = db.collection("groups").document(membership.id).collection("broadcasts")
        do {
            let snapshot = try await collection.order(by: "publishedAt", descending: true).limit(to: 50).getDocuments()
            let currentUid = Auth.auth().currentUser?.uid ?? ""
            let items: [BroadcastListItem] = snapshot.documents.compactMap { doc in
                guard let data = try? doc.data(as: FirestoreBroadcast.self) else { return nil }
                return BroadcastListItem(
                    id: doc.documentID,
                    title: data.title,
                    body: data.body,
                    deadline: data.deadline,
                    requiresAck: data.requiresAck,
                    acked: ackStore.isAcked(doc.documentID) || (!currentUid.isEmpty && data.acknowledgedUserIds.contains(currentUid)),
                    eventId: data.eventId
                )
            }
            return items
        } catch {
            return TenantContentProvider.broadcasts(for: membership)
        }
    }
    
    func fetchInboxItems() async throws -> [InboxItem] {
        let collection = db.collection("groups").document(membership.id).collection("inbox")
        do {
            let snapshot = try await collection.order(by: "createdAt", descending: true).limit(to: 50).getDocuments()
            let items: [InboxItem] = snapshot.documents.compactMap { doc in
                guard let data = try? doc.data(as: FirestoreInboxItem.self) else { return nil }
                return data.toDomain(id: doc.documentID)
            }
            return items
        } catch {
            return TenantContentProvider.inbox(for: membership)
        }
    }
    
    func fetchActivities() async throws -> [ActivityListItem] {
        let collection = db.collection("groups").document(membership.id).collection("activities")
        do {
            let snapshot = try await collection.order(by: "timestamp", descending: true).limit(to: 20).getDocuments()
            return snapshot.documents.compactMap { doc in
                guard let data = try? doc.data(as: FirestoreActivity.self) else { return nil }
                guard let kind = ActivityListItem.Kind(rawValue: data.kind) else { return nil }
                return ActivityListItem(kind: kind, title: data.title, subtitle: data.subtitle, timestamp: data.timestamp)
            }
        } catch {
            return TenantContentProvider.activities(for: membership)
        }
    }
    
    func fetchClockRecords() async throws -> [ClockRecordItem] {
        let collection = db.collection("clock_records")
        do {
            let snapshot = try await collection
                .whereField("groupId", isEqualTo: membership.id)
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                guard let data = try? doc.data(as: FirestoreClockRecord.self) else { return nil }
                guard let status = ClockRecordItem.Status(rawValue: data.status) else { return nil }
                return ClockRecordItem(id: doc.documentID, site: data.siteName, time: data.timestamp, status: status)
            }
        } catch {
            return TenantContentProvider.clockRecords(for: membership)
        }
    }
    
    func fetchAttendanceSnapshot() async throws -> AttendanceSnapshot {
        let document = db.collection("groups").document(membership.id).collection("attendance_snapshots").document("today")
        if let snapshot = try? await document.getDocument(), snapshot.exists,
           let data = try? snapshot.data(as: FirestoreAttendanceSnapshot.self) {
            return data.toDomain()
        }
        return TenantContentProvider.attendanceSnapshot(for: membership)
    }
    
    func fetchESGSummary() async throws -> ESGSummary {
        let document = db.collection("groups").document(membership.id).collection("esg_summary").document("current")
        if let snapshot = try? await document.getDocument(), snapshot.exists,
           let data = try? snapshot.data(as: FirestoreESGSummary.self) {
            return data.toDomain(fallbackPrefix: membership.id)
        }
        return TenantContentProvider.esgSummary(for: membership)
    }
    
    func fetchInsights() async throws -> [InsightSection] {
        let collection = db.collection("groups").document(membership.id).collection("insights")
        do {
            let snapshot = try await collection.getDocuments()
            let entries: [InsightEntry] = snapshot.documents.compactMap { (doc: QueryDocumentSnapshot) -> InsightEntry? in
                guard let data = try? doc.data(as: FirestoreInsight.self) else { return nil }
                return data.toDomain(id: doc.documentID)
            }
            if entries.isEmpty { return TenantContentProvider.insights(for: membership) }
            let grouped = Dictionary(grouping: entries, by: { $0.category })
            return grouped.map { category, entries in
                InsightSection(id: category, title: category.capitalized, entries: entries)
            }
        } catch {
            return TenantContentProvider.insights(for: membership)
        }
    }
    
    func acknowledgeInboxItem(_ item: InboxItem) async throws {
        let document = db.collection("groups").document(membership.id).collection("inbox").document(item.id)
        ackStore.ack(item.id)
        let data: [String: Any] = [
            "acknowledged": true,
            "acknowledgedBy": Auth.auth().currentUser?.uid ?? "",
            "acknowledgedAt": FieldValue.serverTimestamp()
        ]
        _ = try? await document.setData(data, merge: true)
    }
}

/// REST API 的概念性 Adapter，示範如何以設定建立請求。
final class RESTTenantIntegration: TenantIntegrationProtocol {
    private let membership: TenantMembership
    private let configuration: TenantConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(context: TenantIntegrationContext, configuration: TenantConfiguration, session: URLSession = .shared) {
        self.membership = context.membership
        self.configuration = configuration
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }
    
    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let rest = configuration.rest else {
            throw TenantIntegrationError.missingConfiguration("REST 設定缺失")
        }
        let resolvedPath = applyPlaceholders(in: path)
        var components = URLComponents(url: rest.baseURL.appendingPathComponent(resolvedPath), resolvingAgainstBaseURL: false)!
        if !rest.queries.isEmpty {
            components.queryItems = rest.queries.map { key, value in
                URLQueryItem(name: key, value: applyPlaceholders(in: value))
            }
        }
        guard let url = components.url else {
            throw TenantIntegrationError.missingConfiguration("無法建立 URL：\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        rest.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        switch rest.authMethod {
        case .none:
            break
        case .apiKey:
            if let key = rest.credentials["apiKey"], let header = rest.credentials["apiKeyHeader"] {
                request.setValue(key, forHTTPHeaderField: header)
            }
        case .bearerToken:
            if let token = rest.credentials["token"] {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .basic:
            if let user = rest.credentials["username"], let password = rest.credentials["password"] {
                let combined = "\(user):\(password)".data(using: .utf8)?.base64EncodedString() ?? ""
                request.setValue("Basic \(combined)", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }
    
    func fetchBroadcasts() async throws -> [BroadcastListItem] {
        let path = configuration.options["broadcasts.path"] ?? "/broadcasts"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        return try decoder.decode([BroadcastListItem].self, from: data)
    }

    func fetchInboxItems() async throws -> [InboxItem] {
        let path = configuration.options["inbox.path"] ?? "/inbox"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let rawItems = try decoder.decode([RESTInboxItem].self, from: data)
        return rawItems.compactMap { $0.toDomain() }
    }
    
    func fetchActivities() async throws -> [ActivityListItem] {
        let path = configuration.options["activities.path"] ?? "/activities"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let items = try decoder.decode([RESTActivityItem].self, from: data)
        return items.compactMap { $0.toDomain() }
    }
    
    func fetchClockRecords() async throws -> [ClockRecordItem] {
        let path = configuration.options["clock.path"] ?? "/clock-records"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let items = try decoder.decode([RESTClockRecordItem].self, from: data)
        return items.compactMap { $0.toDomain() }
    }
    
    func fetchAttendanceSnapshot() async throws -> AttendanceSnapshot {
        let path = configuration.options["attendance.path"] ?? "/attendance/snapshot"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let snapshot = try decoder.decode(RESTAttendanceSnapshot.self, from: data)
        return snapshot.toDomain()
    }
    
    func fetchESGSummary() async throws -> ESGSummary {
        let path = configuration.options["esg.path"] ?? "/esg/summary"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let summary = try decoder.decode(RESTESGSummary.self, from: data)
        return summary.toDomain()
    }
    
    func fetchInsights() async throws -> [InsightSection] {
        let path = configuration.options["insights.path"] ?? "/insights"
        let request = try makeRequest(path: path)
        let (data, _) = try await session.data(for: request)
        let sections = try decoder.decode([RESTInsightSection].self, from: data)
        return sections.compactMap { $0.toDomain() }
    }
    
    func acknowledgeInboxItem(_ item: InboxItem) async throws {
        let template = configuration.options["inbox.ackPath"] ?? "/inbox/{id}/ack"
        let path = template.replacingOccurrences(of: "{id}", with: item.id)
        let request = try makeRequest(path: path, method: "POST")
        _ = try await session.data(for: request)
    }
    
    private func applyPlaceholders(in value: String) -> String {
        value
            .replacingOccurrences(of: "{{TENANT_ID}}", with: membership.tenant.id)
            .replacingOccurrences(of: "{{MEMBERSHIP_ID}}", with: membership.id)
            .replacingOccurrences(of: "{{ROLE}}", with: membership.role.rawValue)
    }
}

// MARK: - Firestore Model Mapping

private struct FirestoreBroadcast: Codable {
    let title: String
    let body: String
    let requiresAck: Bool
    let deadline: Date?
    let eventId: String?
    let acknowledgedUserIds: [String]
}

private struct FirestoreInboxItem: Codable {
    let kind: String
    let title: String
    let subtitle: String
    let deadline: Date?
    let isUrgent: Bool
    let priority: String
    let eventId: String?
    
    func toDomain(id: String) -> InboxItem? {
        guard let kind = InboxItem.Kind(rawValue: kind), let priority = InboxItem.Priority(rawValue: priority) else { return nil }
        return InboxItem(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            deadline: deadline,
            isUrgent: isUrgent,
            priority: priority,
            eventId: eventId
        )
    }
}

private struct FirestoreActivity: Codable {
    let kind: String
    let title: String
    let subtitle: String
    let timestamp: Date
}

private struct FirestoreClockRecord: Codable {
    let siteName: String
    let timestamp: Date
    let status: String
}

private struct FirestoreAttendanceSnapshot: Codable {
    let courseName: String
    let attendanceTime: Date
    let validDuration: Int
    let stats: AttendanceStats
    let personalRecords: [AttendanceRecord]
    
    func toDomain() -> AttendanceSnapshot {
        AttendanceSnapshot(courseName: courseName, attendanceTime: attendanceTime, validDuration: validDuration, stats: stats, personalRecords: personalRecords)
    }
}

private struct FirestoreESGSummary: Codable {
    struct FirestoreESGRecord: Codable {
        let id: String?
        let title: String
        let subtitle: String
        let timestamp: Date
        
        func toDomain(defaultId: String) -> ESGRecordItem {
            ESGRecordItem(
                id: id ?? defaultId,
                title: title,
                subtitle: subtitle,
                timestamp: timestamp
            )
        }
    }
    
    let progress: String
    let monthlyReduction: String
    let records: [FirestoreESGRecord]?
    
    func toDomain(fallbackPrefix: String) -> ESGSummary {
        let mapped = records?.enumerated().map { index, record in
            record.toDomain(defaultId: "\(fallbackPrefix)-esg-\(index)")
        } ?? []
        return ESGSummary(progress: progress, monthlyReduction: monthlyReduction, records: mapped)
    }
}

private struct FirestoreInsight: Codable {
    let category: String
    let title: String
    let value: String
    let trend: String
    
    func toDomain(id: String) -> InsightEntry {
        InsightEntry(id: id, category: category, title: title, value: value, trend: trend)
    }
}

private struct RESTInboxItem: Decodable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let deadline: Date?
    let isUrgent: Bool
    let priority: String
    let eventId: String?
    
    func toDomain() -> InboxItem? {
        guard let kind = InboxItem.Kind(rawValue: kind), let priority = InboxItem.Priority(rawValue: priority) else { return nil }
        return InboxItem(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            deadline: deadline,
            isUrgent: isUrgent,
            priority: priority,
            eventId: eventId
        )
    }
}

private struct RESTActivityItem: Decodable {
    let kind: String
    let title: String
    let subtitle: String
    let timestamp: Date
    
    func toDomain() -> ActivityListItem? {
        guard let kindValue = ActivityListItem.Kind(rawValue: kind) else { return nil }
        return ActivityListItem(kind: kindValue, title: title, subtitle: subtitle, timestamp: timestamp)
    }
}

private struct RESTClockRecordItem: Decodable {
    let id: String
    let site: String
    let time: Date
    let status: String
    
    func toDomain() -> ClockRecordItem? {
        guard let statusValue = ClockRecordItem.Status(rawValue: status) else { return nil }
        return ClockRecordItem(id: id, site: site, time: time, status: statusValue)
    }
}

private struct RESTAttendanceSnapshot: Decodable {
    struct RESTStats: Decodable {
        let attended: Int
        let absent: Int
        let late: Int
        let total: Int
    }
    
    struct RESTRecord: Decodable {
        let courseName: String
        let date: Date
        let status: String
        
        func toDomain() -> AttendanceRecord? {
            guard let statusValue = AttendanceStatus(rawValue: status) else { return nil }
            return AttendanceRecord(courseName: courseName, date: date, status: statusValue)
        }
    }
    
    let courseName: String
    let attendanceTime: Date
    let validDuration: Int
    let stats: RESTStats
    let personalRecords: [RESTRecord]
    
    func toDomain() -> AttendanceSnapshot {
        AttendanceSnapshot(
            courseName: courseName,
            attendanceTime: attendanceTime,
            validDuration: validDuration,
            stats: AttendanceStats(
                attended: stats.attended,
                absent: stats.absent,
                late: stats.late,
                total: stats.total
            ),
            personalRecords: personalRecords.compactMap { $0.toDomain() }
        )
    }
}

private struct RESTESGSummary: Decodable {
    struct RESTRecord: Decodable {
        let id: String?
        let title: String
        let subtitle: String
        let timestamp: Date
        
        func toDomain(fallbackId: String) -> ESGRecordItem {
            ESGRecordItem(id: id ?? fallbackId, title: title, subtitle: subtitle, timestamp: timestamp)
        }
    }
    
    let progress: String
    let monthlyReduction: String
    let records: [RESTRecord]
    
    func toDomain() -> ESGSummary {
        let mapped = records.enumerated().map { index, element in
            element.toDomain(fallbackId: "esg-\(index)")
        }
        return ESGSummary(progress: progress, monthlyReduction: monthlyReduction, records: mapped)
    }
}

private struct RESTInsightSection: Decodable {
    struct RESTEntry: Decodable {
        let id: String
        let category: String
        let title: String
        let value: String
        let trend: String
        
        func toDomain() -> InsightEntry {
            InsightEntry(id: id, category: category, title: title, value: value, trend: trend)
        }
    }
    
    let id: String
    let title: String
    let entries: [RESTEntry]
    
    func toDomain() -> InsightSection? {
        let mapped = entries.map { $0.toDomain() }
        return InsightSection(id: id, title: title, entries: mapped)
    }
}
