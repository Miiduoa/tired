import Foundation

// MARK: - Date Utilities
/// 統一的日期處理工具，所有日期計算都應使用這些方法
struct DateUtils {

    // MARK: - Date Conversion

    /// Convert timestamp to local date with timezone
    static func toLocalDate(_ timestamp: Date, timeZone: TimeZone = .current) -> Date {
        return timestamp
    }

    /// Get start of day for a date in specific timezone
    static func startOfDay(_ date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    /// Get end of day for a date in specific timezone
    static func endOfDay(_ date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? date
    }

    // MARK: - Date Comparison

    /// Calculate difference in calendar days
    static func diffInCalendarDays(from earlier: Date, to later: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: earlier)
        let end = calendar.startOfDay(for: later)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }

    /// Check if two dates are on the same day
    static func isSameDay(_ date1: Date, _ date2: Date, timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.isDate(date1, inSameDayAs: date2)
    }

    /// Check if date1 is before date2 (calendar day comparison)
    static func isBefore(_ date1: Date, _ date2: Date, timeZone: TimeZone = .current) -> Bool {
        return diffInCalendarDays(from: date1, to: date2, timeZone: timeZone) > 0
    }

    /// Check if date1 is after date2 (calendar day comparison)
    static func isAfter(_ date1: Date, _ date2: Date, timeZone: TimeZone = .current) -> Bool {
        return diffInCalendarDays(from: date2, to: date1, timeZone: timeZone) > 0
    }

    // MARK: - Date Arithmetic

    /// Add days to a date
    static func addDays(_ date: Date, _ days: Int, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Add weeks to a date
    static func addWeeks(_ date: Date, _ weeks: Int, timeZone: TimeZone = .current) -> Date {
        return addDays(date, weeks * 7, timeZone: timeZone)
    }

    /// Add months to a date
    static func addMonths(_ date: Date, _ months: Int, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    // MARK: - Date Formatting

    /// Format date to 'YYYY-MM-DD' string (for denormalized fields)
    static func formatDateKey(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// Parse 'YYYY-MM-DD' string to date
    static func parseDateKey(_ dateKey: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.date(from: dateKey)
    }

    /// Format date for display (e.g., "11月9日 週六")
    static func formatDisplayDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: date)
    }

    /// Format time for display (e.g., "14:30")
    static func formatDisplayTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Format datetime for display (e.g., "11月9日 14:30")
    static func formatDisplayDateTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Week Helpers

    /// Get start of week (Monday) for a date
    static func startOfWeek(_ date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2 // Monday

        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? date
    }

    /// Get end of week (Sunday) for a date
    static func endOfWeek(_ date: Date, timeZone: TimeZone = .current) -> Date {
        let start = startOfWeek(date, timeZone: timeZone)
        return addDays(start, 6, timeZone: timeZone)
    }

    /// Get all dates in a week (Monday to Sunday)
    static func datesInWeek(startingFrom weekStart: Date, timeZone: TimeZone = .current) -> [Date] {
        var dates: [Date] = []
        for i in 0..<7 {
            dates.append(addDays(weekStart, i, timeZone: timeZone))
        }
        return dates
    }

    /// Get weekday (1 = Monday, 7 = Sunday)
    static func weekday(_ date: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2 // Monday
        let weekday = calendar.component(.weekday, from: date)
        // Convert: Sunday (1) -> 7, Monday (2) -> 1, ..., Saturday (7) -> 6
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Check if date is weekend (Saturday or Sunday)
    static func isWeekend(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        let wd = weekday(date, timeZone: timeZone)
        return wd == 6 || wd == 7
    }

    /// Get weekday name (Mon, Tue, etc.)
    static func weekdayName(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Relative Date Helpers

    /// Check if date is today
    static func isToday(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        return isSameDay(date, Date(), timeZone: timeZone)
    }

    /// Check if date is tomorrow
    static func isTomorrow(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        let tomorrow = addDays(Date(), 1, timeZone: timeZone)
        return isSameDay(date, tomorrow, timeZone: timeZone)
    }

    /// Check if date is yesterday
    static func isYesterday(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        let yesterday = addDays(Date(), -1, timeZone: timeZone)
        return isSameDay(date, yesterday, timeZone: timeZone)
    }

    /// Get relative date description (今天, 明天, 昨天, or formatted date)
    static func relativeDateDescription(_ date: Date, timeZone: TimeZone = .current) -> String {
        if isToday(date, timeZone: timeZone) {
            return "今天"
        } else if isTomorrow(date, timeZone: timeZone) {
            return "明天"
        } else if isYesterday(date, timeZone: timeZone) {
            return "昨天"
        } else {
            return formatDisplayDate(date, timeZone: timeZone)
        }
    }

    // MARK: - Time Difference

    /// Calculate difference in minutes between two dates
    static func diffInMinutes(from start: Date, to end: Date) -> Int {
        let interval = end.timeIntervalSince(start)
        return max(Int(interval / 60), 0)
    }

    /// Calculate difference in hours between two dates
    static func diffInHours(from start: Date, to end: Date) -> Int {
        let interval = end.timeIntervalSince(start)
        return max(Int(interval / 3600), 0)
    }

    // MARK: - Clamping

    /// Clamp time to a specific day (used for multi-day events)
    static func clampToDay(_ time: Date, day: Date, isAllDay: Bool, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let dayStart = startOfDay(day, timeZone: timeZone)
        let dayEnd = endOfDay(day, timeZone: timeZone)

        if isAllDay {
            // All-day events: 08:00 - 16:00
            var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
            startComponents.hour = 8
            startComponents.minute = 0
            let allDayStart = calendar.date(from: startComponents) ?? dayStart

            var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
            endComponents.hour = 16
            endComponents.minute = 0
            let allDayEnd = calendar.date(from: endComponents) ?? dayEnd

            if time < allDayStart { return allDayStart }
            if time > allDayEnd { return allDayEnd }
            return time
        } else {
            // Regular events
            if time < dayStart { return dayStart }
            if time > dayEnd { return dayEnd }
            return time
        }
    }
}
