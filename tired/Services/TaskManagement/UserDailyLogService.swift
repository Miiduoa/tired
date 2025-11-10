import Foundation
import FirebaseFirestore

// MARK: - User Daily Log Service
@MainActor
class UserDailyLogService: BaseFirestoreService, ObservableObject {

    static let shared = UserDailyLogService()

    private let COLLECTION = "user_daily_logs"

    @Published var logs: [UserDailyLog] = []

    // MARK: - CRUD Operations

    func createLog(_ log: UserDailyLog) async throws {
        var newLog = log
        newLog.createdAt = Date()
        newLog.updatedAt = Date()

        try await create(newLog, collection: COLLECTION)
    }

    func updateLog(_ log: UserDailyLog) async throws {
        var updatedLog = log
        updatedLog.updatedAt = Date()

        try await update(updatedLog, collection: COLLECTION)
    }

    func getLog(userId: String, date: Date) async throws -> UserDailyLog? {
        let startOfDay = DateUtils.startOfDay(date)
        let endOfDay = DateUtils.endOfDay(date)

        let logs = try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .greaterThanOrEquals(field: "date", value: Timestamp(date: startOfDay)),
                .lessThanOrEquals(field: "date", value: Timestamp(date: endOfDay))
            ],
            limit: 1,
            as: UserDailyLog.self
        )

        return logs.first
    }

    func getRecentLogs(userId: String, days: Int = 7) async throws -> [UserDailyLog] {
        let startDate = DateUtils.addDays(Date(), -days)

        return try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .greaterThanOrEquals(field: "date", value: Timestamp(date: startDate))
            ],
            orderBy: [("date", true)],
            as: UserDailyLog.self
        )
    }

    // MARK: - Update or Create Log

    func saveHighlight(userId: String, date: Date, highlight: String) async throws {
        if let existing = try await getLog(userId: userId, date: date) {
            var updated = existing
            updated.highlight = highlight
            try await updateLog(updated)
        } else {
            let newLog = UserDailyLog(
                userId: userId,
                date: DateUtils.startOfDay(date),
                highlight: highlight
            )
            try await createLog(newLog)
        }
    }

    func saveMood(userId: String, date: Date, mood: UserDailyLog.Mood) async throws {
        if let existing = try await getLog(userId: userId, date: date) {
            var updated = existing
            updated.mood = mood
            try await updateLog(updated)
        } else {
            let newLog = UserDailyLog(
                userId: userId,
                date: DateUtils.startOfDay(date),
                mood: mood
            )
            try await createLog(newLog)
        }
    }

    func saveHighlightAndMood(
        userId: String,
        date: Date,
        highlight: String?,
        mood: UserDailyLog.Mood?
    ) async throws {
        if let existing = try await getLog(userId: userId, date: date) {
            var updated = existing
            if let highlight = highlight {
                updated.highlight = highlight
            }
            if let mood = mood {
                updated.mood = mood
            }
            try await updateLog(updated)
        } else {
            let newLog = UserDailyLog(
                userId: userId,
                date: DateUtils.startOfDay(date),
                highlight: highlight,
                mood: mood
            )
            try await createLog(newLog)
        }
    }

    // MARK: - Query Logs for Experience Export

    func getLogsForTerm(
        userId: String,
        termConfig: TermConfig
    ) async throws -> [UserDailyLog] {
        guard let startDate = termConfig.startDate else {
            return []
        }

        let endDate = termConfig.endDate ?? Date()

        return try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .greaterThanOrEquals(field: "date", value: Timestamp(date: startDate)),
                .lessThanOrEquals(field: "date", value: Timestamp(date: endDate))
            ],
            orderBy: [("date", false)],
            as: UserDailyLog.self
        )
    }

    func getHighlights(userId: String, startDate: Date, endDate: Date) async throws -> [String] {
        let logs = try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .greaterThanOrEquals(field: "date", value: Timestamp(date: startDate)),
                .lessThanOrEquals(field: "date", value: Timestamp(date: endDate))
            ],
            orderBy: [("date", false)],
            as: UserDailyLog.self
        )

        return logs.compactMap { $0.highlight }.filter { !$0.isEmpty }
    }
}
