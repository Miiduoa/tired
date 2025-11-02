import Foundation
import Vision
import UIKit
import VisionKit

/// OCR 文字識別服務
@MainActor
final class OCRService: ObservableObject {
    static let shared = OCRService()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    
    private init() {}
    
    // MARK: - Text Recognition
    
    /// 從圖片中識別文字
    func recognizeText(from image: UIImage, language: RecognitionLanguage = .traditionalChinese) async throws -> RecognizedText {
        isProcessing = true
        progress = 0.0
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = language.codes
        request.usesLanguageCorrection = true
        
        progress = 0.3
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        progress = 0.7
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        var recognizedItems: [RecognizedTextItem] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let boundingBox = observation.boundingBox
            let convertedRect = VNImageRectForNormalizedRect(
                boundingBox,
                Int(image.size.width),
                Int(image.size.height)
            )
            
            let item = RecognizedTextItem(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: convertedRect
            )
            
            recognizedItems.append(item)
        }
        
        progress = 1.0
        
        return RecognizedText(
            fullText: recognizedItems.map { $0.text }.joined(separator: "\n"),
            items: recognizedItems,
            image: image
        )
    }
    
    /// 從多張圖片批量識別
    func recognizeTextBatch(from images: [UIImage], language: RecognitionLanguage = .traditionalChinese) async throws -> [RecognizedText] {
        var results: [RecognizedText] = []
        
        for (index, image) in images.enumerated() {
            let result = try await recognizeText(from: image, language: language)
            results.append(result)
            progress = Double(index + 1) / Double(images.count)
        }
        
        return results
    }
    
    // MARK: - Bill/Invoice Recognition
    
    /// 識別帳單/發票資訊
    func recognizeBill(from image: UIImage) async throws -> BillInfo {
        let recognizedText = try await recognizeText(from: image, language: .traditionalChinese)
        
        // 解析關鍵欄位
        let amount = extractAmount(from: recognizedText.fullText)
        let date = extractDate(from: recognizedText.fullText)
        let merchantName = extractMerchantName(from: recognizedText.fullText)
        let category = inferCategory(from: recognizedText.fullText)
        
        return BillInfo(
            amount: amount,
            date: date,
            merchantName: merchantName,
            category: category,
            rawText: recognizedText.fullText,
            confidence: calculateOverallConfidence(recognizedText.items),
            imageURL: nil
        )
    }
    
    // MARK: - ESG Data Extraction
    
    /// 從電費單中提取 ESG 相關數據
    func extractESGData(from image: UIImage) async throws -> ESGExtractedData {
        let recognizedText = try await recognizeText(from: image, language: .traditionalChinese)
        let text = recognizedText.fullText
        
        // 提取電力消耗
        let powerConsumption = extractPowerConsumption(from: text)
        
        // 提取水消耗（如果有）
        let waterConsumption = extractWaterConsumption(from: text)
        
        // 提取日期範圍
        let periodStart = extractPeriodStart(from: text)
        let periodEnd = extractPeriodEnd(from: text)
        
        // 計算碳排放（使用標準係數）
        let carbonEmission = calculateCarbonEmission(powerKWh: powerConsumption ?? 0)
        
        return ESGExtractedData(
            powerConsumption: powerConsumption,
            waterConsumption: waterConsumption,
            carbonEmission: carbonEmission,
            periodStart: periodStart,
            periodEnd: periodEnd,
            confidence: calculateOverallConfidence(recognizedText.items),
            rawText: text
        )
    }
    
    // MARK: - Document Scanner
    
    @available(iOS 16.0, *)
    func scanDocument() async throws -> [UIImage] {
        let scanner = VNDocumentCameraViewController()
        // Note: 需要在 UIKit 環境中使用
        // 這裡返回模擬數據
        return []
    }
    
    // MARK: - Private Helpers
    
    private func extractAmount(from text: String) -> Double? {
        // 匹配金額模式：$123.45, NT$1,234, 1234元 等
        let patterns = [
            #"(?:NT\$|[$＄])\s*([0-9,]+(?:\.[0-9]{1,2})?)"#,
            #"([0-9,]+(?:\.[0-9]{1,2})?)\s*元"#,
            #"金額[:：]\s*([0-9,]+(?:\.[0-9]{1,2})?)"#,
            #"總計[:：]\s*([0-9,]+(?:\.[0-9]{1,2})?)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                if let amount = Double(amountString) {
                    return amount
                }
            }
        }
        
        return nil
    }
    
    private func extractDate(from text: String) -> Date? {
        // 匹配日期模式：2024/01/15, 2024-01-15, 民國113年1月15日 等
        let patterns = [
            #"(\d{4})[/-](\d{1,2})[/-](\d{1,2})"#,
            #"民國\s*(\d{2,3})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日"#
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                if pattern.contains("民國") {
                    // 處理民國年
                    if let yearRange = Range(match.range(at: 1), in: text),
                       let monthRange = Range(match.range(at: 2), in: text),
                       let dayRange = Range(match.range(at: 3), in: text),
                       let year = Int(text[yearRange]),
                       let month = Int(text[monthRange]),
                       let day = Int(text[dayRange]) {
                        let westernYear = year + 1911
                        let dateString = String(format: "%04d-%02d-%02d", westernYear, month, day)
                        return dateFormatter.date(from: dateString)
                    }
                } else {
                    // 處理西元年
                    if let yearRange = Range(match.range(at: 1), in: text),
                       let monthRange = Range(match.range(at: 2), in: text),
                       let dayRange = Range(match.range(at: 3), in: text) {
                        let dateString = "\(text[yearRange])-\(text[monthRange])-\(text[dayRange])"
                        return dateFormatter.date(from: dateString)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractMerchantName(from text: String) -> String? {
        // 簡單提取：取第一行非空文字
        let lines = text.components(separatedBy: .newlines)
        return lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
    
    private func inferCategory(from text: String) -> BillCategory {
        let lowerText = text.lowercased()
        
        if lowerText.contains("電") || lowerText.contains("power") || lowerText.contains("electricity") {
            return .electricity
        } else if lowerText.contains("水") || lowerText.contains("water") {
            return .water
        } else if lowerText.contains("gas") || lowerText.contains("瓦斯") {
            return .gas
        } else if lowerText.contains("餐") || lowerText.contains("食") || lowerText.contains("restaurant") {
            return .food
        } else if lowerText.contains("交通") || lowerText.contains("transport") {
            return .transportation
        } else {
            return .other
        }
    }
    
    private func extractPowerConsumption(from text: String) -> Double? {
        // 匹配用電度數：123 kWh, 123度 等
        let patterns = [
            #"([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:kWh|度)"#,
            #"用電[:：]\s*([0-9,]+(?:\.[0-9]{1,2})?)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let valueString = String(text[range]).replacingOccurrences(of: ",", with: "")
                if let value = Double(valueString) {
                    return value
                }
            }
        }
        
        return nil
    }
    
    private func extractWaterConsumption(from text: String) -> Double? {
        // 匹配用水度數
        let patterns = [
            #"([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:m³|立方米|度)"#,
            #"用水[:：]\s*([0-9,]+(?:\.[0-9]{1,2})?)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let valueString = String(text[range]).replacingOccurrences(of: ",", with: "")
                if let value = Double(valueString) {
                    return value
                }
            }
        }
        
        return nil
    }
    
    private func extractPeriodStart(from text: String) -> Date? {
        // 提取起始日期
        if let range = text.range(of: #"起始[:：]\s*(\d{4}[/-]\d{1,2}[/-]\d{1,2})"#, options: .regularExpression) {
            let dateString = String(text[range])
            // 解析日期
            return extractDate(from: dateString)
        }
        return nil
    }
    
    private func extractPeriodEnd(from text: String) -> Date? {
        // 提取結束日期
        if let range = text.range(of: #"結束[:：]\s*(\d{4}[/-]\d{1,2}[/-]\d{1,2})"#, options: .regularExpression) {
            let dateString = String(text[range])
            return extractDate(from: dateString)
        }
        return nil
    }
    
    private func calculateCarbonEmission(powerKWh: Double) -> Double {
        // 台灣電力碳排係數約 0.509 kg CO2/kWh（2023年）
        let emissionFactor = 0.509
        return powerKWh * emissionFactor
    }
    
    private func calculateOverallConfidence(_ items: [RecognizedTextItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        let sum = items.reduce(0.0) { $0 + Double($1.confidence) }
        return sum / Double(items.count)
    }
}

// MARK: - Models

enum RecognitionLanguage {
    case english
    case simplifiedChinese
    case traditionalChinese
    case mixed
    
    var codes: [String] {
        switch self {
        case .english:
            return ["en-US"]
        case .simplifiedChinese:
            return ["zh-Hans"]
        case .traditionalChinese:
            return ["zh-Hant"]
        case .mixed:
            return ["zh-Hant", "en-US"]
        }
    }
}

struct RecognizedText {
    let fullText: String
    let items: [RecognizedTextItem]
    let image: UIImage
}

struct RecognizedTextItem {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct BillInfo: Codable {
    let amount: Double?
    let date: Date?
    let merchantName: String?
    let category: BillCategory
    let rawText: String
    let confidence: Double
    let imageURL: String?
}

enum BillCategory: String, Codable {
    case electricity = "電費"
    case water = "水費"
    case gas = "瓦斯費"
    case food = "餐飲"
    case transportation = "交通"
    case shopping = "購物"
    case healthcare = "醫療"
    case entertainment = "娛樂"
    case other = "其他"
}

struct ESGExtractedData {
    let powerConsumption: Double? // kWh
    let waterConsumption: Double? // m³
    let carbonEmission: Double? // kg CO2
    let periodStart: Date?
    let periodEnd: Date?
    let confidence: Double
    let rawText: String
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "無效的圖片"
        case .noTextFound:
            return "未找到文字"
        case .processingFailed(let message):
            return "處理失敗: \(message)"
        }
    }
}

