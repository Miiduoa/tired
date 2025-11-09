import Foundation

/// 應用會話狀態管理
class AppSession: ObservableObject {
    static let shared = AppSession()

    @Published var todayDate: Date = Date()
    @Published var oldLastOpenDate: Date?
    @Published var timeZone: TimeZone = .current

    private init() {}

    /// 更新會話狀態
    func updateSession(with profile: UserProfile) {
        self.todayDate = DateUtils.startOfDay(Date())
        self.oldLastOpenDate = profile.lastOpenDate
        self.timeZone = TimeZone(identifier: profile.timeZone) ?? .current
    }

    /// 獲取今天的日期字符串
    func todayKey() -> String {
        return DateUtils.formatDateKey(todayDate, timeZone: timeZone)
    }

    /// 獲取本週開始日期
    func weekStart() -> Date {
        return DateUtils.startOfWeek(todayDate, timeZone: timeZone)
    }
}
