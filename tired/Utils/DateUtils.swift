import Foundation

/// 統一日期工具類 - 所有日期計算都應該使用這個類
struct DateUtils {

    /// 將 timestamp 轉換為指定時區的本地日期
    static func toLocalDate(_ date: Date, timeZone: TimeZone) -> Date {
        return date
    }

    /// 計算兩個日期之間相差的天數（日曆日）
    static func diffInCalendarDays(_ later: Date, _ earlier: Date, timeZone: TimeZone = .current) -> Int {
        let calendar = Calendar.current
        var calendarWithTZ = calendar
        calendarWithTZ.timeZone = timeZone

        let laterDay = calendarWithTZ.startOfDay(for: later)
        let earlierDay = calendarWithTZ.startOfDay(for: earlier)

        let components = calendarWithTZ.dateComponents([.day], from: earlierDay, to: laterDay)
        return components.day ?? 0
    }

    /// 計算兩個日期之間相差的分鐘數
    static func diffInMinutes(_ later: Date, _ earlier: Date) -> Int {
        return Int(later.timeIntervalSince(earlier) / 60)
    }

    /// 在日期上加上指定天數
    static func addDays(_ date: Date, _ days: Int, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// 檢查日期 a 是否在日期 b 之前（不含同一天）
    static func isBefore(_ a: Date, _ b: Date, timeZone: TimeZone = .current) -> Bool {
        return diffInCalendarDays(b, a, timeZone: timeZone) > 0
    }

    /// 檢查日期 a 是否在日期 b 之後（不含同一天）
    static func isAfter(_ a: Date, _ b: Date, timeZone: TimeZone = .current) -> Bool {
        return diffInCalendarDays(a, b, timeZone: timeZone) > 0
    }

    /// 檢查兩個日期是否是同一天
    static func isSameDay(_ a: Date, _ b: Date, timeZone: TimeZone = .current) -> Bool {
        let calendar = Calendar.current
        var calendarWithTZ = calendar
        calendarWithTZ.timeZone = timeZone

        return calendarWithTZ.isDate(a, inSameDayAs: b)
    }

    /// 格式化日期為 YYYY-MM-DD 字符串（用於反范式欄位）
    static func formatDateKey(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// 從 YYYY-MM-DD 字符串解析日期
    static func parseDateKey(_ dateKey: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.date(from: dateKey)
    }

    /// 獲取當前日期的開始（00:00:00）
    static func startOfDay(_ date: Date = Date(), timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    /// 獲取週的開始日期（週一）
    static func startOfWeek(_ date: Date = Date(), timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2  // Monday = 2

        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    /// 檢查日期是否是週末
    static func isWeekend(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7  // Sunday = 1, Saturday = 7
    }

    /// 獲取日期的星期幾（1-7，週一為1）
    static func weekdayNumber(_ date: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date)
        // Convert from Sunday=1 to Monday=1
        return weekday == 1 ? 7 : weekday - 1
    }

    /// 格式化時間為本地化字符串
    static func formatTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// 格式化日期為本地化字符串
    static func formatDate(_ date: Date, timeZone: TimeZone = .current, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// 格式化日期時間為本地化字符串
    static func formatDateTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// 將事件時間限制在某一天的範圍內
    static func clampToDay(_ date: Date, day: Date, isAllDay: Bool, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        if isAllDay {
            // All-day events: use 08:00-16:00
            let start = calendar.date(byAdding: .hour, value: 8, to: dayStart) ?? dayStart
            if date < start {
                return start
            }
            let end = calendar.date(byAdding: .hour, value: 16, to: dayStart) ?? dayStart
            if date > end {
                return end
            }
            return date
        } else {
            if date < dayStart {
                return dayStart
            }
            if date >= dayEnd {
                return dayEnd
            }
            return date
        }
    }

    /// 獲取今天的日期字符串（用於顯示）
    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: Date())
    }

    /// 獲取相對日期描述（今天、明天、昨天等）
    static func relativeDayDescription(_ date: Date, from: Date = Date(), timeZone: TimeZone = .current) -> String {
        if isSameDay(date, from, timeZone: timeZone) {
            return "今天"
        }

        let tomorrow = addDays(from, 1, timeZone: timeZone)
        if isSameDay(date, tomorrow, timeZone: timeZone) {
            return "明天"
        }

        let yesterday = addDays(from, -1, timeZone: timeZone)
        if isSameDay(date, yesterday, timeZone: timeZone) {
            return "昨天"
        }

        let diff = diffInCalendarDays(date, from, timeZone: timeZone)
        if diff > 0 && diff <= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "zh_TW")
            formatter.timeZone = timeZone
            return formatter.string(from: date)
        }

        return formatDate(date, timeZone: timeZone, style: .short)
    }
}

extension Date {
    /// 便捷方法：格式化為日期鍵
    func toDateKey(timeZone: TimeZone = .current) -> String {
        return DateUtils.formatDateKey(self, timeZone: timeZone)
    }

    /// 便捷方法：檢查是否在另一個日期之前
    func isBefore(_ other: Date, timeZone: TimeZone = .current) -> Bool {
        return DateUtils.isBefore(self, other, timeZone: timeZone)
    }

    /// 便捷方法：檢查是否在另一個日期之後
    func isAfter(_ other: Date, timeZone: TimeZone = .current) -> Bool {
        return DateUtils.isAfter(self, other, timeZone: timeZone)
    }

    /// 便捷方法：檢查是否是同一天
    func isSameDay(as other: Date, timeZone: TimeZone = .current) -> Bool {
        return DateUtils.isSameDay(self, other, timeZone: timeZone)
    }
}
