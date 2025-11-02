import Foundation
import CoreBluetooth
import Combine

/// 藍牙附近交友服務
@MainActor
final class BLENearbyService: NSObject, ObservableObject {
    static let shared = BLENearbyService()
    
    // 服務 UUID（需要在實際使用時生成唯一的 UUID）
    private let serviceUUID = CBUUID(string: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
    private let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var matchedUsers: [NearbyUser] = []
    @Published var authorizationStatus: CBManagerAuthorization = .notDetermined
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var advertisingData: [String: Any] = [:]
    
    // 安全設置
    private var temporaryId: String = ""
    private var rotationTimer: Timer?
    private let idRotationInterval: TimeInterval = 300 // 5分鐘輪換一次 ID
    
    private override init() {
        super.init()
    }
    
    // MARK: - Lifecycle
    
    func start(userId: String, displayName: String, interests: [String]) {
        // 生成臨時 ID
        rotateTemporaryId()
        
        // 準備廣播數據
        let profile = UserProfile(
            userId: temporaryId, // 使用臨時 ID
            displayName: displayName,
            interests: interests
        )
        
        guard let profileData = try? JSONEncoder().encode(profile),
              let profileString = String(data: profileData, encoding: .utf8) else {
            return
        }
        
        // 初始化 Central Manager（掃描）
        centralManager = CBCentralManager(delegate: self, queue: .main)
        
        // 初始化 Peripheral Manager（廣播）
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        
        // 設置 ID 輪換定時器
        startIdRotation()
        
        print("📡 BLE 服務啟動")
    }
    
    func stop() {
        stopScanning()
        stopAdvertising()
        stopIdRotation()
        
        print("📡 BLE 服務停止")
    }
    
    // MARK: - Scanning
    
    private func startScanning() {
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn else {
            print("⚠️ 藍牙未開啟")
            return
        }
        
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        print("🔍 開始掃描附近設備")
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        print("🔍 停止掃描")
    }
    
    // MARK: - Advertising
    
    private func startAdvertising(profileData: Data) {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            print("⚠️ 藍牙未開啟")
            return
        }
        
        // 創建服務
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // 創建特徵值
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .notify],
            value: profileData,
            permissions: [.readable]
        )
        
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        
        // 開始廣播
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "TiredNearby"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        
        print("📢 開始廣播")
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        print("📢 停止廣播")
    }
    
    // MARK: - Matching
    
    func requestMatch(with user: NearbyUser) async throws {
        // 發送配對請求
        print("💌 發送配對請求給: \(user.displayName)")
        
        // TODO: 實現配對邏輯
        // 1. 通過後端 API 發送配對請求
        // 2. 等待對方確認
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 模擬成功
        if !matchedUsers.contains(where: { $0.id == user.id }) {
            matchedUsers.append(user)
        }
    }
    
    func acceptMatch(from user: NearbyUser) async throws {
        print("✅ 接受配對請求: \(user.displayName)")
        
        // TODO: 通知對方配對成功
        
        if !matchedUsers.contains(where: { $0.id == user.id }) {
            matchedUsers.append(user)
        }
    }
    
    func rejectMatch(from user: NearbyUser) {
        print("❌ 拒絕配對請求: \(user.displayName)")
        
        // TODO: 通知對方配對被拒絕
    }
    
    func blockUser(_ user: NearbyUser) {
        print("🚫 封鎖用戶: \(user.displayName)")
        
        // 從附近用戶列表移除
        nearbyUsers.removeAll { $0.id == user.id }
        matchedUsers.removeAll { $0.id == user.id }
        
        // TODO: 添加到封鎖列表
    }
    
    // MARK: - Security
    
    private func rotateTemporaryId() {
        temporaryId = "temp_\(UUID().uuidString)"
        print("🔄 臨時 ID 已輪換: \(temporaryId.prefix(20))...")
    }
    
    private func startIdRotation() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: idRotationInterval, repeats: true) { [weak self] _ in
            self?.rotateTemporaryId()
            // 重新開始廣播使用新的 ID
            self?.stopAdvertising()
            // TODO: 重新開始廣播
        }
    }
    
    private func stopIdRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
    
    // MARK: - Privacy
    
    func reportUser(_ user: NearbyUser, reason: ReportReason) async throws {
        print("🚨 檢舉用戶: \(user.displayName), 原因: \(reason.rawValue)")
        
        // TODO: 發送檢舉到後端
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/reports") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "reportedUserId": user.id,
            "reason": reason.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BLEError.reportFailed
        }
        
        // 自動封鎖該用戶
        blockUser(user)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLENearbyService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        authorizationStatus = central.authorization
        
        switch central.state {
        case .poweredOn:
            print("✅ 藍牙已開啟")
            startScanning()
        case .poweredOff:
            print("⚠️ 藍牙已關閉")
            isScanning = false
        case .unsupported:
            print("❌ 設備不支援藍牙")
        case .unauthorized:
            print("❌ 藍牙未授權")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("📍 發現設備: \(peripheral.identifier)")
        
        // 計算距離（根據 RSSI）
        let distance = calculateDistance(rssi: RSSI.doubleValue)
        
        // 儲存 peripheral
        discoveredPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        
        // 連接以讀取特徵值
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔗 已連接: \(peripheral.identifier)")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 已斷開: \(peripheral.identifier)")
    }
    
    private func calculateDistance(rssi: Double) -> Double {
        // 簡化的距離估算公式
        let txPower: Double = -59 // 1米處的參考 RSSI 值
        
        if rssi == 0 {
            return -1
        }
        
        let ratio = rssi / txPower
        if ratio < 1.0 {
            return pow(ratio, 10)
        } else {
            return (0.89976) * pow(ratio, 7.7095) + 0.111
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLENearbyService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == characteristicUUID,
              let data = characteristic.value,
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        
        // 創建附近用戶
        let nearbyUser = NearbyUser(
            id: profile.userId,
            displayName: profile.displayName,
            interests: profile.interests,
            distance: 0.0, // TODO: 計算實際距離
            lastSeen: Date()
        )
        
        // 更新附近用戶列表
        if !nearbyUsers.contains(where: { $0.id == nearbyUser.id }) {
            nearbyUsers.append(nearbyUser)
            print("👤 發現新用戶: \(nearbyUser.displayName)")
        }
        
        // 斷開連接
        centralManager?.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLENearbyService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("✅ Peripheral 藍牙已開啟")
            // TODO: 開始廣播
        case .poweredOff:
            print("⚠️ Peripheral 藍牙已關閉")
            isAdvertising = false
        default:
            break
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("❌ 廣播失敗: \(error)")
            isAdvertising = false
        } else {
            print("✅ 廣播成功")
            isAdvertising = true
        }
    }
}

// MARK: - Models

struct NearbyUser: Identifiable, Codable {
    let id: String
    let displayName: String
    let interests: [String]
    let distance: Double // 單位：米
    let lastSeen: Date
    
    var distanceString: String {
        if distance < 1 {
            return "< 1m"
        } else if distance < 10 {
            return String(format: "%.1fm", distance)
        } else {
            return String(format: "%.0fm", distance)
        }
    }
}

private struct UserProfile: Codable {
    let userId: String
    let displayName: String
    let interests: [String]
}

enum ReportReason: String, Codable {
    case spam = "垃圾訊息"
    case harassment = "騷擾"
    case inappropriate = "不當內容"
    case fake = "假帳號"
    case other = "其他"
}

enum BLEError: LocalizedError {
    case bluetoothOff
    case unauthorized
    case scanningFailed
    case advertisingFailed
    case reportFailed
    
    var errorDescription: String? {
        switch self {
        case .bluetoothOff:
            return "藍牙未開啟"
        case .unauthorized:
            return "未授權使用藍牙"
        case .scanningFailed:
            return "掃描失敗"
        case .advertisingFailed:
            return "廣播失敗"
        case .reportFailed:
            return "檢舉失敗"
        }
    }
}

