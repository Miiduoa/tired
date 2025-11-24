import Foundation

extension Date {
    /// 格式化为 "MM/dd (EEE)"
    func formatShort() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd (EEE)"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: self)
    }

    /// 格式化为 "HH:mm"
    func formatTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// 格式化为 "M月d日 EEEE"
    func formatLong() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: self)
    }

    /// 格式化为 "yyyy年M月d日 HH:mm"
    func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }

    /// 是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// 是否在本周
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// 本周的开始（周一）
    static func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    /// 从今天开始的本周7天
    static func daysOfWeek(startingFrom date: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }
}

extension Calendar {
    /// 获取两个日期之间的天数
    func daysBetween(_ from: Date, _ to: Date) -> Int {
        let components = dateComponents([.day], from: from, to: to)
        return components.day ?? 0
    }
}
