import XCTest
@testable import tired

@MainActor
final class AIServiceTests: XCTestCase {
    
    var service: AIService!
    
    override func setUpWithError() throws {
        service = AIService.shared
    }
    
    override func tearDownWithError() throws {
        service = nil
    }
    
    // MARK: - Broadcast Drafting Tests
    
    func testGenerateBroadcastDraft() async throws {
        // Given
        let topic = "重要會議通知"
        let audience = "全體員工"
        
        // When
        let drafts = try await service.generateBroadcastDraft(
            topic: topic,
            audience: audience,
            tone: .formal
        )
        
        // Then
        XCTAssertFalse(drafts.isEmpty, "應該至少生成一個草稿")
        XCTAssertEqual(drafts.count, 3, "應該生成3個草稿")
        
        for draft in drafts {
            XCTAssertFalse(draft.title.isEmpty, "標題不應為空")
            XCTAssertFalse(draft.body.isEmpty, "內容不應為空")
            XCTAssertTrue(draft.body.contains(topic), "內容應包含主題")
        }
    }
    
    func testGenerateBroadcastDraftWithDeadline() async throws {
        // Given
        let topic = "作業繳交"
        let audience = "學生"
        let deadline = Date().addingTimeInterval(86400 * 7) // 7天後
        
        // When
        let drafts = try await service.generateBroadcastDraft(
            topic: topic,
            audience: audience,
            tone: .friendly,
            includeDeadline: true,
            deadline: deadline
        )
        
        // Then
        XCTAssertFalse(drafts.isEmpty)
        // 檢查至少有一個草稿包含截止日期相關文字
        let hasDeadline = drafts.contains { $0.body.contains("前") || $0.body.contains("截止") }
        XCTAssertTrue(hasDeadline, "應該包含截止日期資訊")
    }
    
    // MARK: - Summarization Tests
    
    func testSummarize() async throws {
        // Given
        let longText = """
        這是一段很長的文字內容。它包含了許多重要的資訊。
        第一點是關於專案的進度更新。第二點是關於團隊協作。
        第三點是關於未來的規劃。我們需要在下週完成所有任務。
        請大家注意截止日期，並及時回報進度。謝謝大家的配合。
        """
        
        // When
        let summary = try await service.summarize(text: longText, maxLength: 100)
        
        // Then
        XCTAssertFalse(summary.isEmpty, "摘要不應為空")
        XCTAssertLessThanOrEqual(summary.count, 150, "摘要長度應該合理")
    }
    
    // MARK: - Sentiment Analysis Tests
    
    func testAnalyzeSentimentPositive() async throws {
        // Given
        let positiveText = "今天真是美好的一天！我完成了所有任務，感覺很開心。"
        
        // When
        let result = try await service.analyzeSentiment(text: positiveText)
        
        // Then
        XCTAssertEqual(result.emotion, .positive, "應該識別為正面情緒")
        XCTAssertGreaterThan(result.score, 0, "分數應該為正數")
    }
    
    func testAnalyzeSentimentNegative() async throws {
        // Given
        let negativeText = "今天很糟糕，什麼都不順利，很沮喪。"
        
        // When
        let result = try await service.analyzeSentiment(text: negativeText)
        
        // Then
        XCTAssertEqual(result.emotion, .negative, "應該識別為負面情緒")
        XCTAssertLessThan(result.score, 0, "分數應該為負數")
    }
    
    func testAnalyzeSentimentNeutral() async throws {
        // Given
        let neutralText = "今天天氣晴朗。我去了超市買東西。"
        
        // When
        let result = try await service.analyzeSentiment(text: neutralText)
        
        // Then
        XCTAssertEqual(result.emotion, .neutral, "應該識別為中性情緒")
    }
    
    func testAnalyzeSentimentBatch() async throws {
        // Given
        let texts = [
            "很開心！",
            "很難過。",
            "今天天氣不錯。"
        ]
        
        // When
        let results = try await service.analyzeSentimentBatch(texts: texts)
        
        // Then
        XCTAssertEqual(results.count, texts.count, "應該返回相同數量的結果")
    }
    
    // MARK: - CBT Nudge Tests
    
    func testGenerateCBTNudgeForNegativeEmotion() async throws {
        // Given
        let situation = "考試成績不理想"
        
        // When
        let nudge = try await service.generateCBTNudge(situation: situation, emotion: .negative)
        
        // Then
        XCTAssertEqual(nudge.situation, situation)
        XCTAssertEqual(nudge.emotion, .negative)
        XCTAssertFalse(nudge.reframingQuestions.isEmpty, "應該包含重構問題")
        XCTAssertFalse(nudge.suggestedAction.isEmpty, "應該包含建議行動")
        XCTAssertGreaterThan(nudge.estimatedTime, 0, "應該有預估時間")
    }
    
    func testGenerateCBTNudgeForAnxiousEmotion() async throws {
        // Given
        let situation = "明天有重要面試"
        
        // When
        let nudge = try await service.generateCBTNudge(situation: situation, emotion: .anxious)
        
        // Then
        XCTAssertEqual(nudge.emotion, .anxious)
        XCTAssertFalse(nudge.reframingQuestions.isEmpty)
        XCTAssertFalse(nudge.suggestedAction.isEmpty)
    }
    
    func testGenerateCBTNudgeForStressedEmotion() async throws {
        // Given
        let situation = "工作量太大"
        
        // When
        let nudge = try await service.generateCBTNudge(situation: situation, emotion: .stressed)
        
        // Then
        XCTAssertEqual(nudge.emotion, .stressed)
        XCTAssertFalse(nudge.reframingQuestions.isEmpty)
        XCTAssertTrue(nudge.suggestedAction.contains("番茄鐘") || nudge.suggestedAction.contains("休息"))
    }
    
    // MARK: - Thread Summarization Tests
    
    func testSummarizeThread() async throws {
        // Given
        let messages = [
            ThreadMessage(senderId: "user1", senderName: "Alice", content: "大家好，關於下週的會議", timestamp: Date()),
            ThreadMessage(senderId: "user2", senderName: "Bob", content: "我覺得我們需要討論預算問題", timestamp: Date()),
            ThreadMessage(senderId: "user3", senderName: "Charlie", content: "請大家準備好報告", timestamp: Date()),
            ThreadMessage(senderId: "user1", senderName: "Alice", content: "會議定在週三下午2點", timestamp: Date())
        ]
        
        // When
        let summary = try await service.summarizeThread(messages: messages)
        
        // Then
        XCTAssertFalse(summary.summary.isEmpty, "摘要不應為空")
        XCTAssertEqual(summary.messageCount, messages.count, "訊息數量應該匹配")
        XCTAssertGreaterThan(summary.participants.count, 0, "應該有參與者")
    }
}

