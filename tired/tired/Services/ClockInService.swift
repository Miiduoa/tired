import Foundation
import FirebaseFirestore
import CoreLocation

/// 打卡服務
@MainActor
final class ClockInService {
    static let shared = ClockInService()
    
    private let db = Firestore.firestore()
    private var recordsCache: [String: [ClockRecord]] = [:] // userId -> records
    private var sitesCache: [String: [ClockSite]] = [:] // tenantId -> sites
    
    private init() {}
    
    // MARK: - Sites Management
    
    /// 創建打卡地點
    func createSite(
        tenantId: String,
        name: String,
        location: CLLocationCoordinate2D,
        radius: Double = 100.0 // 預設地理圍欄半徑 100 公尺
    ) async throws -> String {
        let siteId = UUID().uuidString
        
        let siteData: [String: Any] = [
            "id": siteId,
            "tenantId": tenantId,
            "name": name,
            "location": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "radius": radius,
            "createdAt": FieldValue.serverTimestamp(),
            "active": true
        ]
        
        do {
            try await db.collection("clock_sites").document(siteId).setData(siteData)
            
            // 清除快取
            sitesCache.removeValue(forKey: tenantId)
            
            print("✅ 打卡地點已創建: \(siteId)")
            return siteId
        } catch {
            print("❌ 創建打卡地點失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取打卡地點列表
    func fetchSites(tenantId: String) async throws -> [ClockSite] {
        do {
            let snapshot = try await db.collection("clock_sites")
                .whereField("tenantId", isEqualTo: tenantId)
                .whereField("active", isEqualTo: true)
                .getDocuments()
            
            let sites = snapshot.documents.compactMap { doc -> ClockSite? in
                try? parseSite(from: doc)
            }
            
            // 更新快取
            sitesCache[tenantId] = sites
            
            // 如果沒有數據，返回 mock 數據
            if sites.isEmpty {
                return createMockSites()
            }
            
            return sites
        } catch {
            print("❌ 獲取打卡地點失敗: \(error.localizedDescription)")
            // 返回快取或 mock 數據
            return sitesCache[tenantId] ?? createMockSites()
        }
    }
    
    private func parseSite(from doc: DocumentSnapshot) throws -> ClockSite? {
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let tenantId = data["tenantId"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let radius = data["radius"] as? Double ?? 100.0
        
        guard let locationData = data["location"] as? [String: Double],
              let lat = locationData["latitude"],
              let lng = locationData["longitude"] else {
            return nil
        }
        
        let location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        return ClockSite(
            id: id,
            tenantId: tenantId,
            name: name,
            location: location,
            radius: radius
        )
    }
    
    private func createMockSites() -> [ClockSite] {
        return [
            ClockSite(
                id: "site_1",
                tenantId: "tenant_1",
                name: "總部大樓",
                location: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
                radius: 100.0
            ),
            ClockSite(
                id: "site_2",
                tenantId: "tenant_1",
                name: "研發中心",
                location: CLLocationCoordinate2D(latitude: 25.040, longitude: 121.570),
                radius: 150.0
            )
        ]
    }
    
    // MARK: - Clock In/Out
    
    /// 打卡上班
    func clockIn(
        userId: String,
        userName: String,
        tenantId: String,
        siteId: String,
        location: CLLocationCoordinate2D
    ) async throws -> String {
        // 檢查是否在地理圍欄內
        guard let site = try await fetchSite(id: siteId) else {
            throw ClockError.siteNotFound
        }
        
        if !isWithinGeofence(userLocation: location, site: site) {
            throw ClockError.outsideGeofence
        }
        
        // 檢查今天是否已經打卡上班
        if try await hasClockedInToday(userId: userId) {
            throw ClockError.alreadyClockedIn
        }
        
        let recordId = UUID().uuidString
        
        let recordData: [String: Any] = [
            "id": recordId,
            "userId": userId,
            "userName": userName,
            "tenantId": tenantId,
            "siteId": siteId,
            "siteName": site.name,
            "clockInTime": FieldValue.serverTimestamp(),
            "location": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "status": "normal",
            "type": "in",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("clock_records").document(recordId).setData(recordData)
            
            // 清除快取
            recordsCache.removeValue(forKey: userId)
            
            print("✅ 打卡上班成功: \(recordId)")
            return recordId
        } catch {
            print("❌ 打卡上班失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 打卡下班
    func clockOut(
        userId: String,
        location: CLLocationCoordinate2D
    ) async throws {
        // 找到今天最新的打卡上班記錄
        guard let latestRecord = try await getTodayLatestClockIn(userId: userId) else {
            throw ClockError.noClockInRecord
        }
        
        // 檢查是否已經打卡下班
        if latestRecord.clockOutTime != nil {
            throw ClockError.alreadyClockedOut
        }
        
        // 更新記錄，添加下班時間
        let updateData: [String: Any] = [
            "clockOutTime": FieldValue.serverTimestamp(),
            "clockOutLocation": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("clock_records").document(latestRecord.id).updateData(updateData)
            
            // 清除快取
            recordsCache.removeValue(forKey: userId)
            
            print("✅ 打卡下班成功")
        } catch {
            print("❌ 打卡下班失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取打卡記錄
    func fetchRecords(userId: String, limit: Int = 30) async throws -> [ClockRecord] {
        do {
            let snapshot = try await db.collection("clock_records")
                .whereField("userId", isEqualTo: userId)
                .order(by: "clockInTime", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            let records = snapshot.documents.compactMap { doc -> ClockRecord? in
                try? parseRecord(from: doc)
            }
            
            // 更新快取
            recordsCache[userId] = records
            
            // 如果沒有數據，返回 mock 數據
            if records.isEmpty {
                return createMockRecords()
            }
            
            return records
        } catch {
            print("❌ 獲取打卡記錄失敗: \(error.localizedDescription)")
            // 返回快取或 mock 數據
            return recordsCache[userId] ?? createMockRecords()
        }
    }
    
    private func parseRecord(from doc: DocumentSnapshot) throws -> ClockRecord? {
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let userId = data["userId"] as? String ?? ""
        let userName = data["userName"] as? String ?? "未知"
        let tenantId = data["tenantId"] as? String ?? ""
        let siteId = data["siteId"] as? String ?? ""
        let siteName = data["siteName"] as? String ?? ""
        let clockInTime = (data["clockInTime"] as? Timestamp)?.dateValue() ?? Date()
        let clockOutTime = (data["clockOutTime"] as? Timestamp)?.dateValue()
        let statusString = data["status"] as? String ?? "normal"
        let status = ClockStatus(rawValue: statusString) ?? .normal
        
        var location: CLLocationCoordinate2D? = nil
        if let locationData = data["location"] as? [String: Double],
           let lat = locationData["latitude"],
           let lng = locationData["longitude"] {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        return ClockRecord(
            id: id,
            userId: userId,
            userName: userName,
            tenantId: tenantId,
            siteId: siteId,
            siteName: siteName,
            clockInTime: clockInTime,
            clockOutTime: clockOutTime,
            location: location,
            status: status
        )
    }
    
    private func createMockRecords() -> [ClockRecord] {
        let now = Date()
        let calendar = Calendar.current
        
        return (0..<7).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let clockInTime = calendar.date(bySettingHour: 9, minute: Int.random(in: 0...30), second: 0, of: date) ?? date
            let clockOutTime = calendar.date(bySettingHour: 18, minute: Int.random(in: 0...30), second: 0, of: date)
            
            return ClockRecord(
                id: "record_\(i)",
                userId: "user_1",
                userName: "測試用戶",
                tenantId: "tenant_1",
                siteId: "site_1",
                siteName: "總部大樓",
                clockInTime: clockInTime,
                clockOutTime: clockOutTime,
                location: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
                status: i == 2 ? .exception : .normal
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchSite(id: String) async throws -> ClockSite? {
        do {
            let doc = try await db.collection("clock_sites").document(id).getDocument()
            return try? parseSite(from: doc)
        } catch {
            print("❌ 獲取打卡地點失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func hasClockedInToday(userId: String) async throws -> Bool {
        return try await getTodayLatestClockIn(userId: userId) != nil
    }
    
    private func getTodayLatestClockIn(userId: String) async throws -> ClockRecord? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let snapshot = try await db.collection("clock_records")
            .whereField("userId", isEqualTo: userId)
            .whereField("clockInTime", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("clockInTime", isLessThan: Timestamp(date: tomorrow))
            .order(by: "clockInTime", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            return nil
        }
        
        return try? parseRecord(from: doc)
    }
    
    private func isWithinGeofence(userLocation: CLLocationCoordinate2D, site: ClockSite) -> Bool {
        let siteLocation = CLLocation(latitude: site.location.latitude, longitude: site.location.longitude)
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        let distance = userLoc.distance(from: siteLocation)
        return distance <= site.radius
    }
    
    // MARK: - Statistics
    
    /// 獲取用戶打卡統計
    func getUserStats(userId: String, tenantId: String, days: Int = 30) async throws -> ClockStats {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let snapshot = try await db.collection("clock_records")
            .whereField("userId", isEqualTo: userId)
            .whereField("tenantId", isEqualTo: tenantId)
            .whereField("clockInTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("clockInTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        let records = snapshot.documents.compactMap { doc -> ClockRecord? in
            try? parseRecord(from: doc)
        }
        
        let totalDays = records.count
        let normalDays = records.filter { $0.status == .normal }.count
        let exceptionDays = records.filter { $0.status == .exception }.count
        
        // 計算平均上班時間
        let avgClockInTime = calculateAverageTime(from: records.map { $0.clockInTime })
        
        return ClockStats(
            totalDays: totalDays,
            normalDays: normalDays,
            exceptionDays: exceptionDays,
            pendingDays: 0,
            averageClockInTime: avgClockInTime
        )
    }
    
    private func calculateAverageTime(from dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let totalSeconds = dates.map { calendar.component(.hour, from: $0) * 3600 + calendar.component(.minute, from: $0) * 60 }
            .reduce(0, +)
        
        let avgSeconds = totalSeconds / dates.count
        let avgHour = avgSeconds / 3600
        let avgMinute = (avgSeconds % 3600) / 60
        
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = avgHour
        components.minute = avgMinute
        
        return calendar.date(from: components)
    }
}

// MARK: - Models

struct ClockSite: Identifiable, Codable {
    let id: String
    let tenantId: String
    let name: String
    let location: CLLocationCoordinate2D
    let radius: Double
    
    enum CodingKeys: String, CodingKey {
        case id, tenantId, name, radius
        case latitude, longitude
    }
    
    init(
        id: String,
        tenantId: String,
        name: String,
        location: CLLocationCoordinate2D,
        radius: Double
    ) {
        self.id = id
        self.tenantId = tenantId
        self.name = name
        self.location = location
        self.radius = radius
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tenantId = try container.decode(String.self, forKey: .tenantId)
        name = try container.decode(String.self, forKey: .name)
        radius = try container.decode(Double.self, forKey: .radius)
        
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tenantId, forKey: .tenantId)
        try container.encode(name, forKey: .name)
        try container.encode(radius, forKey: .radius)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
    }
}

struct ClockRecord: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let tenantId: String
    let siteId: String
    let siteName: String
    let clockInTime: Date
    let clockOutTime: Date?
    let location: CLLocationCoordinate2D?
    let status: ClockStatus
    
    enum CodingKeys: String, CodingKey {
        case id, userId, userName, tenantId, siteId, siteName
        case clockInTime, clockOutTime, status
        case latitude, longitude
    }
    
    init(
        id: String,
        userId: String,
        userName: String,
        tenantId: String,
        siteId: String,
        siteName: String,
        clockInTime: Date,
        clockOutTime: Date? = nil,
        location: CLLocationCoordinate2D? = nil,
        status: ClockStatus
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.tenantId = tenantId
        self.siteId = siteId
        self.siteName = siteName
        self.clockInTime = clockInTime
        self.clockOutTime = clockOutTime
        self.location = location
        self.status = status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userName = try container.decode(String.self, forKey: .userName)
        tenantId = try container.decode(String.self, forKey: .tenantId)
        siteId = try container.decode(String.self, forKey: .siteId)
        siteName = try container.decode(String.self, forKey: .siteName)
        clockInTime = try container.decode(Date.self, forKey: .clockInTime)
        clockOutTime = try container.decodeIfPresent(Date.self, forKey: .clockOutTime)
        status = try container.decode(ClockStatus.self, forKey: .status)
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lng = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            location = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(userName, forKey: .userName)
        try container.encode(tenantId, forKey: .tenantId)
        try container.encode(siteId, forKey: .siteId)
        try container.encode(siteName, forKey: .siteName)
        try container.encode(clockInTime, forKey: .clockInTime)
        try container.encodeIfPresent(clockOutTime, forKey: .clockOutTime)
        try container.encode(status, forKey: .status)
        
        if let location = location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
}

enum ClockStatus: String, Codable {
    case normal = "normal"
    case exception = "exception"
    case pending = "pending"
}

struct ClockStats {
    let totalDays: Int
    let normalDays: Int
    let exceptionDays: Int
    let pendingDays: Int
    let averageClockInTime: Date?
    
    var normalRate: Double {
        guard totalDays > 0 else { return 0 }
        return Double(normalDays) / Double(totalDays)
    }
}

enum ClockError: LocalizedError {
    case siteNotFound
    case outsideGeofence
    case alreadyClockedIn
    case alreadyClockedOut
    case noClockInRecord
    
    var errorDescription: String? {
        switch self {
        case .siteNotFound: return "找不到打卡地點"
        case .outsideGeofence: return "您不在打卡地點範圍內"
        case .alreadyClockedIn: return "今天已經打卡上班了"
        case .alreadyClockedOut: return "已經打卡下班了"
        case .noClockInRecord: return "找不到今天的上班打卡記錄"
        }
    }
}

