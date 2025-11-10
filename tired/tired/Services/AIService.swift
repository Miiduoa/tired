import Foundation
import NaturalLanguage

/// AI 輔助服務（公告撰稿、摘要生成、情緒分析）
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isProcessing = false
    
    private let apiEndpoint: String?
    private let openAIKey: String?
    
    private init() {
        apiEndpoint = ProcessInfo.processInfo.environment["TIRED_AI_API_URL"]
        openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    
    // MARK: - Broadcast Drafting
    
    /// 生成公告草稿
    func generateBroadcastDraft(
        topic: String,
        audience: String,
        tone: BroadcastTone = .formal,
        includeDeadline: Bool = false,
        deadline: Date? = nil
    ) async throws -> [BroadcastDraft] {
        isProcessing = true
        defer { isProcessing = false }
        
        // 如果有 AI API，使用 API
        if let endpoint = apiEndpoint, let url = URL(string: "\(endpoint)/v1/ai/broadcast/draft") {
            return try await generateDraftViaAPI(
                url: url,
                topic: topic,
                audience: audience,
                tone: tone,
                includeDeadline: includeDeadline,
                deadline: deadline
            )
        }
        
        // 否則使用本地模板生成
        return generateDraftLocally(
            topic: topic,
            audience: audience,
            tone: tone,
            includeDeadline: includeDeadline,
            deadline: deadline
        )
    }
    
    private func generateDraftViaAPI(
        url: URL,
        topic: String,
        audience: String,
        tone: BroadcastTone,
        includeDeadline: Bool,
        deadline: Date?
    ) async throws -> [BroadcastDraft] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = openAIKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        var payload: [String: Any] = [
            "topic": topic,
            "audience": audience,
            "tone": tone.rawValue,
            "count": 3
        ]
        
        if includeDeadline, let deadline = deadline {
            payload["deadline"] = ISO8601DateFormatter().string(from: deadline)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.apiFailed
        }
        
        let result = try JSONDecoder().decode(BroadcastDraftResponse.self, from: data)
        return result.drafts
    }
    
    private func generateDraftLocally(
        topic: String,
        audience: String,
        tone: BroadcastTone,
        includeDeadline: Bool,
        deadline: Date?
    ) -> [BroadcastDraft] {
        let deadlineText = includeDeadline && deadline != nil ? "\n\n請於 \(formatDate(deadline!)) 前完成。" : ""
        
        let templates: [(String, String)] = [
            // 模板 1：簡潔版
            (
                "關於\(topic)的通知",
                "各位\(audience)好：\n\n茲通知\(topic)相關事項，請各位注意並配合辦理。\(deadlineText)\n\n謝謝。"
            ),
            // 模板 2：詳細版
            (
                "重要通知：\(topic)",
                "親愛的\(audience)：\n\n為提升作業效率，現就\(topic)事宜通知如下：\n\n1. 請詳閱相關內容\n2. 如有疑問請洽相關部門\n3. 請準時完成\(deadlineText)\n\n感謝您的配合。"
            ),
            // 模板 3：友善版
            (
                "[\(topic)] 提醒通知",
                "Hi \(audience)！\n\n關於\(topic)，有幾件事情想跟大家分享：\n\n• 請大家留意相關細節\n• 有任何問題都歡迎提出\(deadlineText)\n\n謝謝大家！"
            )
        ]
        
        return templates.enumerated().map { index, template in
            BroadcastDraft(
                id: "local_\(index)",
                title: template.0,
                body: template.1,
                tone: tone,
                score: 0.8
            )
        }
    }
    
    // MARK: - Text Summarization
    
    /// 生成摘要
    func summarize(text: String, maxLength: Int = 200) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // 如果有 AI API，使用 API
        if let endpoint = apiEndpoint, let url = URL(string: "\(endpoint)/v1/ai/summarize") {
            return try await summarizeViaAPI(url: url, text: text, maxLength: maxLength)
        }
        
        // 否則使用本地提取式摘要
        return summarizeLocally(text: text, maxLength: maxLength)
    }
    
    private func summarizeViaAPI(url: URL, text: String, maxLength: Int) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = openAIKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: Any] = [
            "text": text,
            "maxLength": maxLength
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.apiFailed
        }
        
        let result = try JSONDecoder().decode(SummarizeResponse.self, from: data)
        return result.summary
    }
    
    private func summarizeLocally(text: String, maxLength: Int) -> String {
        // 簡單的提取式摘要：取前 N 個句子
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var summary = ""
        for sentence in sentences {
            if summary.count + sentence.count > maxLength {
                break
            }
            summary += sentence + "。"
        }
        
        return summary.isEmpty ? String(text.prefix(maxLength)) : summary
    }
    
    // MARK: - Sentiment Analysis
    
    /// 情緒分析
    func analyzeSentiment(text: String) async throws -> SentimentResult {
        isProcessing = true
        defer { isProcessing = false }
        
        // 使用 NaturalLanguage framework 進行本地情緒分析
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        let score = Double(sentiment?.rawValue ?? "0") ?? 0.0
        
        // 分類情緒
        let emotion: Emotion
        if score > 0.3 {
            emotion = .positive
        } else if score < -0.3 {
            emotion = .negative
        } else {
            emotion = .neutral
        }
        
        return SentimentResult(
            emotion: emotion,
            score: score,
            confidence: abs(score)
        )
    }
    
    /// 批量情緒分析
    func analyzeSentimentBatch(texts: [String]) async throws -> [SentimentResult] {
        var results: [SentimentResult] = []
        
        for text in texts {
            let result = try await analyzeSentiment(text: text)
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - Thread Summarization
    
    /// 對話串摘要
    func summarizeThread(messages: [ThreadMessage]) async throws -> ThreadSummary {
        isProcessing = true
        defer { isProcessing = false }
        
        // 提取關鍵資訊
        var participants = Set<String>()
        var actionItems: [ActionItem] = []
        var keywords: [String] = []
        
        for message in messages {
            participants.insert(message.senderName)
            
            // 提取行動項目（包含「請」、「需要」、「必須」等關鍵字）
            if message.content.contains("請") || message.content.contains("需要") || message.content.contains("必須") {
                let item = ActionItem(
                    description: message.content,
                    assignee: nil,
                    deadline: extractDeadline(from: message.content),
                    completed: false
                )
                actionItems.append(item)
            }
        }
        
        // 提取關鍵字
        let allText = messages.map { $0.content }.joined(separator: " ")
        keywords = extractKeywords(from: allText)
        
        // 生成摘要
        let summary = try await summarize(text: allText, maxLength: 300)
        
        return ThreadSummary(
            summary: summary,
            participants: Array(participants),
            actionItems: actionItems,
            keywords: keywords,
            messageCount: messages.count
        )
    }
    
    // MARK: - CBT Nudge
    
    /// 生成 CBT 提示卡
    func generateCBTNudge(situation: String, emotion: Emotion) async throws -> CBTNudge {
        isProcessing = true
        defer { isProcessing = false }
        
        // 根據情緒生成不同的提示
        let nudges: [String]
        let action: String
        
        switch emotion {
        case .negative:
            nudges = [
                "嘗試從不同角度看待這個情況",
                "這個想法是否基於事實？",
                "過去類似的情況，結果如何？",
                "如果朋友遇到同樣的事，你會怎麼建議？"
            ]
            action = "深呼吸 3 次，然後寫下 3 件今天順利的事"
        case .positive:
            nudges = [
                "很棒！記得慶祝這個小勝利",
                "想想是什麼幫助你達成的",
                "這個經驗可以如何應用到其他地方？"
            ]
            action = "花 2 分鐘記錄這個正面經驗"
        case .neutral:
            nudges = [
                "今天有什麼值得感恩的事？",
                "可以為今天設定一個小目標嗎？"
            ]
            action = "列出今天的 3 個優先事項"
        case .anxious:
            nudges = [
                "最壞的情況是什麼？真的會發生嗎？",
                "我能控制什麼？不能控制什麼？",
                "深呼吸，專注當下"
            ]
            action = "4-7-8 呼吸法：吸氣 4 秒，憋氣 7 秒，吐氣 8 秒"
        case .stressed:
            nudges = [
                "把大任務分成小步驟",
                "休息一下也是工作的一部分",
                "向他人尋求協助是可以的"
            ]
            action = "番茄鐘工作法：專注 25 分鐘，休息 5 分鐘"
        }
        
        return CBTNudge(
            situation: situation,
            emotion: emotion,
            reframingQuestions: nudges,
            suggestedAction: action,
            estimatedTime: 10
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func extractDeadline(from text: String) -> Date? {
        // 簡單的日期提取
        // TODO: 實現更複雜的日期解析
        return nil
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let keyword = String(text[range])
                if keyword.count > 1 { // 過濾單字元
                    keywords.append(keyword)
                }
            }
            return true
        }
        
        // 去重並限制數量
        return Array(Set(keywords)).prefix(10).map { $0 }
    }
}

// MARK: - Models

enum BroadcastTone: String, Codable {
    case formal = "正式"
    case casual = "輕鬆"
    case urgent = "緊急"
    case friendly = "友善"
}

struct BroadcastDraft: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let tone: BroadcastTone
    let score: Double // 品質分數 0-1
}

struct BroadcastDraftResponse: Codable {
    let drafts: [BroadcastDraft]
}

struct SummarizeResponse: Codable {
    let summary: String
}

enum Emotion: String, Codable {
    case positive = "正面"
    case negative = "負面"
    case neutral = "中性"
    case anxious = "焦慮"
    case stressed = "壓力"
}

struct SentimentResult {
    let emotion: Emotion
    let score: Double // -1 到 1
    let confidence: Double // 0 到 1
}

struct ThreadMessage {
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
}

struct ThreadSummary {
    let summary: String
    let participants: [String]
    let actionItems: [ActionItem]
    let keywords: [String]
    let messageCount: Int
}

struct ActionItem: Identifiable {
    let id = UUID()
    let description: String
    let assignee: String?
    let deadline: Date?
    let completed: Bool
}

struct CBTNudge {
    let situation: String
    let emotion: Emotion
    let reframingQuestions: [String]
    let suggestedAction: String
    let estimatedTime: Int // 分鐘
}

enum AIError: LocalizedError {
    case apiFailed
    case invalidResponse
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .apiFailed:
            return "AI API 請求失敗"
        case .invalidResponse:
            return "無效的 AI 回應"
        case .noAPIKey:
            return "未設定 API 金鑰"
        }
    }
}

