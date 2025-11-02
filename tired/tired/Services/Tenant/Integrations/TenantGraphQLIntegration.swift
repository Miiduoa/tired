import Foundation

/// GraphQL 版本的租戶整合 Adapter。
/// 使用 TenantConfiguration.options 來指定 endpoint 與查詢字串：
/// - options["graphql.endpoint"]: GraphQL 端點 URL（必填）
/// - options["gql.broadcasts"]、["gql.inbox"]、["gql.activities"]、["gql.clock"]、["gql.attendance"]、["gql.esg"]、["gql.insights"]：可覆寫預設查詢
/// - options 內凡是以 "graphql.header." 開頭者，會帶到 HTTP Header（例如 graphql.header.Authorization: Bearer <token>）
final class GraphQLTenantIntegration: TenantIntegrationProtocol {
    private let membership: TenantMembership
    private let endpoint: URL
    private let headers: [String: String]
    private let decoder: JSONDecoder

    init(context: TenantIntegrationContext, configuration: TenantConfiguration) {
        self.membership = context.membership
        guard let endpointStr = configuration.options["graphql.endpoint"],
              let url = URL(string: endpointStr) else {
            // 退回至一個無效 URL；實際抓取時會丟錯而被上層降級
            self.endpoint = URL(string: "https://invalid.local/graphql")!
            print("⚠️ GraphQL endpoint 未設定，請於 TenantConfiguration.options[graphql.endpoint] 指定")
            self.headers = [:]
            self.decoder = JSONDecoder()
            self.decoder.dateDecodingStrategy = .iso8601
            self.decoder.keyDecodingStrategy = .convertFromSnakeCase
            return
        }
        self.endpoint = url
        var extraHeaders: [String: String] = [:]
        for (k, v) in configuration.options where k.lowercased().hasPrefix("graphql.header.") {
            let headerName = String(k.dropFirst("graphql.header.".count))
            extraHeaders[headerName] = v
        }
        self.headers = extraHeaders
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - Public

    func fetchBroadcasts() async throws -> [BroadcastListItem] {
        struct DataEnvelope: Decodable { let broadcasts: [BroadcastListItem]? }
        let query = defaultQuery(.broadcasts)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        return data.broadcasts ?? []
    }

    func fetchInboxItems() async throws -> [InboxItem] {
        struct DataEnvelope: Decodable { let inboxItems: [InboxItem]? }
        let query = defaultQuery(.inbox)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        return data.inboxItems ?? []
    }

    func fetchActivities() async throws -> [ActivityListItem] {
        // GraphQL 回傳的活動可直接對應 domain；若 schema 不同，請在後端調整 resolver 或於此加 mapping。
        struct RawActivity: Decodable {
            let kind: String
            let title: String
            let subtitle: String
            let timestamp: Date
        }
        struct DataEnvelope: Decodable { let activities: [RawActivity]? }
        let query = defaultQuery(.activities)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        let raws = data.activities ?? []
        return raws.compactMap { r in
            guard let k = ActivityListItem.Kind(rawValue: r.kind) else { return nil }
            return ActivityListItem(kind: k, title: r.title, subtitle: r.subtitle, timestamp: r.timestamp)
        }
    }

    func fetchClockRecords() async throws -> [ClockRecordItem] {
        struct RawClock: Decodable { let id: String; let site: String; let time: Date; let status: String }
        struct DataEnvelope: Decodable { let clockRecords: [RawClock]? }
        let query = defaultQuery(.clock)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        return (data.clockRecords ?? []).compactMap { raw in
            guard let status = ClockRecordItem.Status(rawValue: raw.status) else { return nil }
            return ClockRecordItem(id: raw.id, site: raw.site, time: raw.time, status: status)
        }
    }

    func fetchAttendanceSnapshot() async throws -> AttendanceSnapshot {
        struct DataEnvelope: Decodable { let attendanceSnapshot: AttendanceSnapshot? }
        let query = defaultQuery(.attendance)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        if let snap = data.attendanceSnapshot { return snap }
        throw TenantIntegrationError.missingConfiguration("attendanceSnapshot not provided")
    }

    func fetchESGSummary() async throws -> ESGSummary {
        struct DataEnvelope: Decodable { let esgSummary: ESGSummary? }
        let query = defaultQuery(.esg)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        if let s = data.esgSummary { return s }
        throw TenantIntegrationError.missingConfiguration("esgSummary not provided")
    }

    func fetchInsights() async throws -> [InsightSection] {
        struct DataEnvelope: Decodable { let insights: [InsightSection]? }
        let query = defaultQuery(.insights)
        let data: DataEnvelope = try await perform(query: query, variables: ["groupId": membership.id])
        return data.insights ?? []
    }

    func acknowledgeInboxItem(_ item: InboxItem) async throws {
        let mutation = defaultMutation(.ackInbox)
        _ = try await perform(query: mutation, variables: ["groupId": membership.id, "itemId": item.id]) as EmptyData
    }

    // MARK: - Internals

    private enum QueryKey: String { case broadcasts, inbox, activities, clock, attendance, esg, insights }
    private enum MutationKey: String { case ackInbox }

    private func defaultQuery(_ key: QueryKey) -> String {
        // 可由 options 覆蓋
        if let custom = membership.configuration?.options["gql.\(key.rawValue)"] { return custom }
        switch key {
        case .broadcasts:
            return """
            query Broadcasts($groupId: ID!){
              broadcasts(groupId: $groupId){ id title body deadline requiresAck acked eventId }
            }
            """
        case .inbox:
            return """
            query Inbox($groupId: ID!){
              inboxItems(groupId: $groupId){ id kind title subtitle deadline isUrgent priority eventId }
            }
            """
        case .activities:
            return """
            query Activities($groupId: ID!){
              activities(groupId: $groupId){ kind title subtitle timestamp }
            }
            """
        case .clock:
            return """
            query Clock($groupId: ID!){
              clockRecords(groupId: $groupId){ id site time status }
            }
            """
        case .attendance:
            return """
            query Attendance($groupId: ID!){
              attendanceSnapshot(groupId: $groupId){
                courseName attendanceTime validDuration
                stats{ attended absent late total }
                personalRecords{ courseName date status }
              }
            }
            """
        case .esg:
            return """
            query ESG($groupId: ID!){
              esgSummary(groupId: $groupId){
                progress monthlyReduction
                records{ id title subtitle timestamp }
              }
            }
            """
        case .insights:
            return """
            query Insights($groupId: ID!){
              insights(groupId: $groupId){ id title entries{ id category title value trend } }
            }
            """
        }
    }

    private func defaultMutation(_ key: MutationKey) -> String {
        if let custom = membership.configuration?.options["gql.mutation.\(key.rawValue)"] { return custom }
        switch key {
        case .ackInbox:
            return """
            mutation Ack($groupId: ID!, $itemId: ID!){
              ackInboxItem(groupId: $groupId, itemId: $itemId)
            }
            """
        }
    }

    private struct GraphQLResponse<T: Decodable>: Decodable {
        let data: T?
        let errors: [GraphQLError]?
    }
    private struct GraphQLError: Decodable { let message: String }
    private struct EmptyData: Decodable {}

    private func perform<T: Decodable>(query: String, variables: [String: Any]) async throws -> T {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        let body: [String: Any] = ["query": query, "variables": variables]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TenantIntegrationError.missingConfiguration("GraphQL HTTP error")
        }
        let decoded = try decoder.decode(GraphQLResponse<T>.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw TenantIntegrationError.missingConfiguration(errors.first?.message ?? "GraphQL error")
        }
        guard let payload = decoded.data else {
            throw TenantIntegrationError.missingConfiguration("GraphQL no data")
        }
        return payload
    }
}

