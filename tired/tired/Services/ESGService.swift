import Foundation
import FirebaseFirestore
import UIKit

/// ESG 數據追蹤和報告服務
@MainActor
final class ESGService {
    static let shared = ESGService()
    
    private let db = Firestore.firestore()
    private var recordsCache: [String: [ESGRecord]] = [:] // tenantId -> records
    
    private init() {}
    
    // MARK: - Records Management
    
    /// 創建 ESG 記錄
    func createRecord(
        tenantId: String,
        category: ESGCategory,
        value: Double,
        unit: String,
        description: String? = nil,
        imageURL: String? = nil,
        metadata: [String: String] = [:]
    ) async throws -> String {
        let recordId = UUID().uuidString
        
        let recordData: [String: Any] = [
            "id": recordId,
            "tenantId": tenantId,
            "category": category.rawValue,
            "value": value,
            "unit": unit,
            "description": description as Any,
            "imageURL": imageURL as Any,
            "metadata": metadata,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        do {
            try await db.collection("esg_records").document(recordId).setData(recordData)
            
            // 清除快取
            recordsCache.removeValue(forKey: tenantId)
            
            print("✅ ESG 記錄已創建: \(recordId)")
            return recordId
        } catch {
            print("❌ 創建 ESG 記錄失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 獲取 ESG 記錄列表
    func fetchRecords(tenantId: String, category: ESGCategory? = nil, limit: Int = 50) async throws -> [ESGRecord] {
        do {
            var query: Query = db.collection("esg_records")
                .whereField("tenantId", isEqualTo: tenantId)
            
            if let category = category {
                query = query.whereField("category", isEqualTo: category.rawValue)
            }
            
            let snapshot = try await query
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            let records = snapshot.documents.compactMap { doc -> ESGRecord? in
                try? parseRecord(from: doc)
            }
            
            // 更新快取
            recordsCache[tenantId] = records
            
            // 如果沒有數據，返回 mock 數據
            if records.isEmpty {
                return createMockRecords()
            }
            
            return records
        } catch {
            print("❌ 獲取 ESG 記錄失敗: \(error.localizedDescription)")
            // 返回快取或 mock 數據
            return recordsCache[tenantId] ?? createMockRecords()
        }
    }
    
    private func parseRecord(from doc: DocumentSnapshot) throws -> ESGRecord? {
        guard let data = doc.data() else { return nil }
        
        let id = doc.documentID
        let tenantId = data["tenantId"] as? String ?? ""
        let categoryString = data["category"] as? String ?? "energy"
        let category = ESGCategory(rawValue: categoryString) ?? .energy
        let value = data["value"] as? Double ?? 0
        let unit = data["unit"] as? String ?? ""
        let description = data["description"] as? String
        let imageURL = data["imageURL"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return ESGRecord(
            id: id,
            tenantId: tenantId,
            category: category,
            value: value,
            unit: unit,
            description: description,
            imageURL: imageURL,
            createdAt: createdAt
        )
    }
    
    private func createMockRecords() -> [ESGRecord] {
        let now = Date()
        return [
            ESGRecord(
                id: "esg_1",
                tenantId: "tenant_1",
                category: .energy,
                value: 1250.5,
                unit: "kWh",
                description: "本月用電量",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-86400 * 1)
            ),
            ESGRecord(
                id: "esg_2",
                tenantId: "tenant_1",
                category: .water,
                value: 85.3,
                unit: "立方公尺",
                description: "本月用水量",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-86400 * 2)
            ),
            ESGRecord(
                id: "esg_3",
                tenantId: "tenant_1",
                category: .waste,
                value: 320.0,
                unit: "公斤",
                description: "本月廢棄物",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-86400 * 3)
            ),
            ESGRecord(
                id: "esg_4",
                tenantId: "tenant_1",
                category: .carbon,
                value: 2.5,
                unit: "公噸 CO2e",
                description: "本月碳排放量",
                imageURL: nil,
                createdAt: now.addingTimeInterval(-86400 * 4)
            )
        ]
    }
    
    // MARK: - OCR Processing
    
    /// 處理帳單 OCR
    func processInvoiceOCR(imageData: Data) async throws -> OCRResult {
        // 這裡應該調用 OCR API（如 Google Vision API 或其他）
        // 目前返回模擬數據
        print("📄 處理 OCR 中...")
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 模擬處理時間
        
        return OCRResult(
            fields: [
                "invoice_number": "2024010001",
                "date": "2024-01-15",
                "amount": "1250.50",
                "vendor": "台電公司",
                "category": "electricity"
            ],
            confidence: 0.95
        )
    }
    
    /// 從 OCR 結果創建 ESG 記錄
    func createRecordFromOCR(
        tenantId: String,
        ocrResult: OCRResult,
        imageURL: String
    ) async throws -> String {
        // 從 OCR 結果提取數據
        let amount = Double(ocrResult.fields["amount"] ?? "0") ?? 0
        let vendor = ocrResult.fields["vendor"] ?? "未知供應商"
        
        // 判斷類別
        let categoryString = ocrResult.fields["category"] ?? "energy"
        let category = ESGCategory(rawValue: categoryString) ?? .energy
        
        // 判斷單位
        let unit: String
        switch category {
        case .energy:
            unit = "kWh"
        case .water:
            unit = "立方公尺"
        case .waste:
            unit = "公斤"
        case .carbon:
            unit = "公噸 CO2e"
        }
        
        return try await createRecord(
            tenantId: tenantId,
            category: category,
            value: amount,
            unit: unit,
            description: "來自 \(vendor) 的帳單",
            imageURL: imageURL,
            metadata: ocrResult.fields
        )
    }
    
    // MARK: - Statistics & Reports
    
    /// 獲取 ESG 統計
    func getStatistics(tenantId: String, startDate: Date, endDate: Date) async throws -> ESGStatistics {
        let records = try await fetchRecords(tenantId: tenantId)
        
        // 過濾日期範圍
        let filteredRecords = records.filter { record in
            record.createdAt >= startDate && record.createdAt <= endDate
        }
        
        // 按類別分組統計
        var categoryTotals: [ESGCategory: Double] = [:]
        for record in filteredRecords {
            categoryTotals[record.category, default: 0] += record.value
        }
        
        // 計算碳排放（簡化計算）
        let energyTotal = categoryTotals[.energy] ?? 0
        let carbonEmission = energyTotal * 0.502 / 1000 // 台灣電力排放係數約 0.502 kg CO2e/kWh
        
        return ESGStatistics(
            energyConsumption: categoryTotals[.energy] ?? 0,
            waterConsumption: categoryTotals[.water] ?? 0,
            wasteGeneration: categoryTotals[.waste] ?? 0,
            carbonEmission: carbonEmission,
            recordCount: filteredRecords.count,
            period: DateInterval(start: startDate, end: endDate)
        )
    }
    
    /// 生成 ESG 報告
    func generateReport(tenantId: String, startDate: Date, endDate: Date) async throws -> ESGReport {
        let statistics = try await getStatistics(tenantId: tenantId, startDate: startDate, endDate: endDate)
        
        // 生成報告內容
        let reportContent = """
        ESG 報告
        報告期間：\(formatDate(startDate)) 至 \(formatDate(endDate))
        
        能源消耗：\(String(format: "%.2f", statistics.energyConsumption)) kWh
        用水量：\(String(format: "%.2f", statistics.waterConsumption)) 立方公尺
        廢棄物：\(String(format: "%.2f", statistics.wasteGeneration)) 公斤
        碳排放：\(String(format: "%.2f", statistics.carbonEmission)) 公噸 CO2e
        
        數據來源：\(statistics.recordCount) 筆記錄
        """
        
        return ESGReport(
            id: UUID().uuidString,
            tenantId: tenantId,
            period: DateInterval(start: startDate, end: endDate),
            statistics: statistics,
            content: reportContent,
            generatedAt: Date()
        )
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - Models

enum ESGCategory: String, Codable, CaseIterable {
    case energy = "energy"
    case water = "water"
    case waste = "waste"
    case carbon = "carbon"
    
    var displayName: String {
        switch self {
        case .energy: return "能源"
        case .water: return "用水"
        case .waste: return "廢棄物"
        case .carbon: return "碳排放"
        }
    }
    
    var icon: String {
        switch self {
        case .energy: return "bolt.fill"
        case .water: return "drop.fill"
        case .waste: return "trash.fill"
        case .carbon: return "leaf.fill"
        }
    }
}

struct ESGRecord: Identifiable, Codable {
    let id: String
    let tenantId: String
    let category: ESGCategory
    let value: Double
    let unit: String
    let description: String?
    let imageURL: String?
    let createdAt: Date
}

struct OCRResult {
    let fields: [String: String]
    let confidence: Double
}

struct ESGStatistics {
    let energyConsumption: Double
    let waterConsumption: Double
    let wasteGeneration: Double
    let carbonEmission: Double
    let recordCount: Int
    let period: DateInterval
}

struct ESGReport {
    let id: String
    let tenantId: String
    let period: DateInterval
    let statistics: ESGStatistics
    let content: String
    let generatedAt: Date
}

