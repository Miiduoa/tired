import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Course Schedule (課程時間表)

/// 課程時間表模型
struct CourseSchedule: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var organizationId: String
    
    // 時間資訊
    var dayOfWeek: Int              // 1=週日, 2=週一, ..., 7=週六
    var startTime: String           // "09:00" 格式
    var endTime: String             // "10:30" 格式
    
    // 地點和教師
    var location: String?           // 教室位置
    var instructor: String?         // 授課教師
    var instructorId: String?       // 教師用戶 ID
    
    // 學期資訊
    var semester: String?            // "2024-1" (學年-學期)
    var weekRange: String?          // "1-18" (第幾週到第幾週)
    
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case dayOfWeek
        case startTime
        case endTime
        case location
        case instructor
        case instructorId
        case semester
        case weekRange
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        organizationId: String,
        dayOfWeek: Int,
        startTime: String,
        endTime: String,
        location: String? = nil,
        instructor: String? = nil,
        instructorId: String? = nil,
        semester: String? = nil,
        weekRange: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationId = organizationId
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.instructor = instructor
        self.instructorId = instructorId
        self.semester = semester
        self.weekRange = weekRange
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Course Schedule Extensions

extension CourseSchedule {
    /// 星期幾的中文名稱
    var dayName: String {
        let days = ["", "週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        return days[safe: dayOfWeek] ?? "未知"
    }
    
    /// 時間範圍顯示
    var timeRange: String {
        return "\(startTime) - \(endTime)"
    }
    
    /// 完整顯示（星期 + 時間）
    var fullDisplay: String {
        return "\(dayName) \(timeRange)"
    }
    
    /// 是否在指定日期
    func isOnDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == dayOfWeek
    }
    
    /// 獲取下次上課時間
    func nextClassTime(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 解析時間
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        guard let startTimeDate = timeFormatter.date(from: startTime) else { return nil }
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTimeDate)
        
        // 計算目標日期
        var daysToAdd = dayOfWeek - weekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // 下週
        }
        
        guard let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: date) else {
            return nil
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = startComponents.hour
        components.minute = startComponents.minute
        
        return calendar.date(from: components)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

