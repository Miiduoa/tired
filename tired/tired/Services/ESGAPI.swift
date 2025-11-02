import Foundation

enum ESGAPIError: Error {
    case invalidURL
    case requestFailed(String)
    case invalidFileFormat
    case uploadFailed
}

/// ESG 碳排管理 API 服務
struct ESGAPI {
    
    // MARK: - 上傳能源數據
    
    /// 上傳能源消耗數據
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - energyType: 能源類型（電力、天然氣等）
    ///   - consumption: 消耗量
    ///   - unit: 單位（kWh, m³等）
    ///   - period: 統計期間
    ///   - bill: 帳單圖片 URL（可選）
    /// - Returns: 記錄 ID
    static func uploadEnergyData(
        groupId: String,
        energyType: String,
        consumption: Double,
        unit: String,
        period: DateInterval,
        bill: String? = nil
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/esg/energy-data")
        else {
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "groupId": groupId,
            "energyType": energyType,
            "consumption": consumption,
            "unit": unit,
            "startDate": ISO8601DateFormatter().string(from: period.start),
            "endDate": ISO8601DateFormatter().string(from: period.end)
        ]
        
        if let bill = bill {
            payload["billUrl"] = bill
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESGAPIError.requestFailed("Failed to upload energy data")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = obj["id"] as? String {
            return id
        }
        
        return "remote-\(UUID().uuidString)"
    }
    
    // MARK: - 上傳減碳措施
    
    /// 記錄減碳措施
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - title: 措施標題
    ///   - description: 措施描述
    ///   - expectedReduction: 預期減碳量（kg CO₂）
    ///   - evidence: 證據文件 URLs
    static func submitReductionMeasure(
        groupId: String,
        title: String,
        description: String,
        expectedReduction: Double,
        evidence: [String]? = nil
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/esg/reduction-measures")
        else {
            return "local-\(UUID().uuidString)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "groupId": groupId,
            "title": title,
            "description": description,
            "expectedReduction": expectedReduction
        ]
        
        if let evidence = evidence {
            payload["evidence"] = evidence
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESGAPIError.requestFailed("Failed to submit reduction measure")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = obj["id"] as? String {
            return id
        }
        
        return "remote-\(UUID().uuidString)"
    }
    
    // MARK: - 生成碳排報表
    
    /// 生成碳排放報表
    /// - Parameters:
    ///   - groupId: 組織 ID
    ///   - period: 統計期間
    ///   - format: 報表格式（pdf, excel）
    /// - Returns: 報表 URL
    static func generateReport(
        groupId: String,
        period: DateInterval,
        format: ReportFormat = .pdf
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/esg/reports")
        else {
            // 離線模式：返回模擬 URL
            return "https://example.com/reports/mock-report.pdf"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "groupId": groupId,
            "startDate": ISO8601DateFormatter().string(from: period.start),
            "endDate": ISO8601DateFormatter().string(from: period.end),
            "format": format.rawValue
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESGAPIError.requestFailed("Failed to generate report")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let reportUrl = obj["reportUrl"] as? String {
            return reportUrl
        }
        
        throw ESGAPIError.requestFailed("Invalid response format")
    }
    
    // MARK: - 獲取 ESG 摘要
    
    /// 獲取 ESG 統計摘要
    static func fetchSummary(groupId: String) async throws -> ESGSummary {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/esg/summary?groupId=\(groupId)")
        else {
            // 離線模式
            return ESGSummary.mock()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESGAPIError.requestFailed("Failed to fetch ESG summary")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ESGSummary.self, from: data)
    }
    
    // MARK: - 帳單 OCR 解析
    
    /// 上傳並解析電費帳單
    /// - Parameter imageData: 帳單圖片數據
    /// - Returns: 解析結果
    static func parseBill(imageData: Data) async throws -> BillParseResult {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/esg/parse-bill")
        else {
            // 離線模式：返回模擬數據
            return BillParseResult(
                consumption: 1250.5,
                unit: "kWh",
                amount: 3750.0,
                period: DateInterval(start: Date().addingTimeInterval(-2592000), end: Date()),
                confidence: 0.95
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"bill\"; filename=\"bill.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESGAPIError.requestFailed("Failed to parse bill")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BillParseResult.self, from: data)
    }
}

// MARK: - 輔助數據結構

enum ReportFormat: String, Codable {
    case pdf
    case excel
}

struct BillParseResult: Codable {
    let consumption: Double
    let unit: String
    let amount: Double
    let period: DateInterval
    let confidence: Double
}

// MARK: - Mock 數據

extension ESGSummary {
    static func mock() -> ESGSummary {
        return ESGSummary(
            progress: "82%",
            monthlyReduction: "-12%",
            records: [
                ESGRecordItem(
                    id: "1",
                    title: "辦公室照明優化",
                    subtitle: "更換 LED 燈具，預計年減碳 500kg",
                    timestamp: Date()
                ),
                ESGRecordItem(
                    id: "2",
                    title: "空調溫度調整",
                    subtitle: "夏季溫度設定 26°C，預計年減碳 300kg",
                    timestamp: Date().addingTimeInterval(-86400)
                )
            ]
        )
    }
}

