import XCTest
@testable import tired
import UIKit

@MainActor
final class OCRServiceTests: XCTestCase {
    
    var service: OCRService!
    
    override func setUpWithError() throws {
        service = OCRService.shared
    }
    
    override func tearDownWithError() throws {
        service = nil
    }
    
    // MARK: - Bill Recognition Tests
    
    func testExtractAmountFromText() {
        // Given
        let testCases = [
            ("總計：NT$1,234.56", 1234.56),
            ("金額: 999元", 999.0),
            ("$500.00", 500.0)
        ]
        
        // When & Then
        for (text, expectedAmount) in testCases {
            // 這裡需要通過反射或其他方式測試私有方法
            // 或者將私有方法改為內部方法以便測試
        }
    }
    
    func testInferCategoryFromText() {
        // Given
        let testCases: [(String, BillCategory)] = [
            ("台灣電力公司 電費單", .electricity),
            ("自來水費 帳單", .water),
            ("天然氣費用通知", .gas),
            ("餐廳消費明細", .food),
            ("計程車費用", .transportation)
        ]
        
        // When & Then
        // 測試類別推斷邏輯
    }
    
    // MARK: - ESG Data Extraction Tests
    
    func testExtractPowerConsumption() {
        // Given
        let testCases = [
            ("本期用電：123 kWh", 123.0),
            ("用電度數 456度", 456.0)
        ]
        
        // When & Then
        // 測試電力消耗提取邏輯
    }
    
    func testCalculateCarbonEmission() {
        // Given
        let powerConsumption = 100.0 // kWh
        let expectedEmission = 100.0 * 0.509 // 使用台灣電力碳排係數
        
        // When
        // 調用計算方法
        
        // Then
        // XCTAssertEqual(result, expectedEmission, accuracy: 0.01)
    }
    
    // MARK: - Date Extraction Tests
    
    func testExtractDateWestern() {
        // Given
        let testCases = [
            "日期：2024/01/15",
            "2024-01-15",
            "繳費期限: 2024.01.15"
        ]
        
        // When & Then
        // 測試西元日期提取
    }
    
    func testExtractDateROC() {
        // Given
        let testText = "民國113年1月15日"
        // 應該轉換為 2024-01-15
        
        // When & Then
        // 測試民國日期提取和轉換
    }
    
    // MARK: - Image Recognition Tests (需要實際圖片)
    
    func testRecognizeTextFromImage() async throws {
        // 這個測試需要實際的測試圖片
        // 可以使用 XCTestCase 的 bundle 來載入測試資源
        
        // Given
        // guard let testImage = UIImage(named: "test_receipt", in: Bundle(for: type(of: self)), with: nil) else {
        //     XCTFail("找不到測試圖片")
        //     return
        // }
        
        // When
        // let result = try await service.recognizeText(from: testImage)
        
        // Then
        // XCTAssertFalse(result.fullText.isEmpty)
        // XCTAssertGreaterThan(result.items.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testRecognitionPerformance() throws {
        // 測試 OCR 性能
        // measure {
        //     // 執行 OCR 操作
        // }
    }
}

