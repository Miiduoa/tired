import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 打卡服務 - Moodle 風格的時間追蹤
class ClockService {
    private let db = FirebaseManager.shared.db

    // MARK: - Clock In/Out Operations

    /// 打卡上班
    func clockIn(
        userId: String,
        taskId: String? = nil,
        organizationId: String? = nil,
        workDescription: String? = nil,
        location: String? = nil,
        category: String? = nil
    ) async throws -> ClockRecord {
        // 檢查是否有進行中的打卡記錄
        let activeRecord = try await getActiveClockRecord(userId: userId)
        if activeRecord != nil {
            throw NSError(
                domain: "ClockService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "已有進行中的打卡記錄，請先打卡下班"]
            )
        }

        let record = ClockRecord(
            userId: userId,
            taskId: taskId,
            organizationId: organizationId,
            clockInTime: Date(),
            workDescription: workDescription,
            location: location,
            category: category
        )

        let docRef = try db.collection("clockRecords").addDocument(from: record)
        var createdRecord = record
        createdRecord.id = docRef.documentID

        print("✅ Clock in successful: \(docRef.documentID)")
        return createdRecord
    }

    /// 打卡下班
    func clockOut(recordId: String, workDescription: String? = nil) async throws -> ClockRecord {
        let recordRef = db.collection("clockRecords").document(recordId)

        var updates: [String: Any] = [
            "clockOutTime": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        if let description = workDescription {
            updates["workDescription"] = description
        }

        try await recordRef.updateData(updates)

        // 獲取更新後的記錄
        let updatedRecord = try await getClockRecord(recordId: recordId)
        print("✅ Clock out successful: \(recordId), Duration: \(updatedRecord.formattedDuration)")

        return updatedRecord
    }

    /// 獲取單個打卡記錄
    func getClockRecord(recordId: String) async throws -> ClockRecord {
        let doc = try await db.collection("clockRecords").document(recordId).getDocument()
        return try doc.data(as: ClockRecord.self)
    }

    /// 獲取用戶當前進行中的打卡記錄
    func getActiveClockRecord(userId: String) async throws -> ClockRecord? {
        let snapshot = try await db.collection("clockRecords")
            .whereField("userId", isEqualTo: userId)
            .whereField("clockOutTime", isEqualTo: NSNull())
            .order(by: "clockInTime", descending: true)
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first?.data(as: ClockRecord.self)
    }

    /// 獲取用戶的打卡記錄（實時監聽）
    func getUserClockRecords(userId: String, limit: Int = 50) -> AnyPublisher<[ClockRecord], Error> {
        let subject = PassthroughSubject<[ClockRecord], Error>()

        db.collection("clockRecords")
            .whereField("userId", isEqualTo: userId)
            .order(by: "clockInTime", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let records = documents.compactMap { doc -> ClockRecord? in
                    try? doc.data(as: ClockRecord.self)
                }

                subject.send(records)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 獲取指定日期範圍的打卡記錄
    func getClockRecords(
        userId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [ClockRecord] {
        let snapshot = try await db.collection("clockRecords")
            .whereField("userId", isEqualTo: userId)
            .whereField("clockInTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("clockInTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "clockInTime", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { doc -> ClockRecord? in
            try? doc.data(as: ClockRecord.self)
        }
    }

    /// 獲取任務相關的打卡記錄
    func getTaskClockRecords(taskId: String) async throws -> [ClockRecord] {
        let snapshot = try await db.collection("clockRecords")
            .whereField("taskId", isEqualTo: taskId)
            .order(by: "clockInTime", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { doc -> ClockRecord? in
            try? doc.data(as: ClockRecord.self)
        }
    }

    // MARK: - Statistics

    /// 計算工時統計
    func calculateWorkStatistics(
        userId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> WorkStatistics {
        let records = try await getClockRecords(
            userId: userId,
            startDate: startDate,
            endDate: endDate
        )

        // 只統計已打卡下班的記錄
        let completedRecords = records.filter { $0.clockOutTime != nil }

        // 總工時
        let totalHours = completedRecords.reduce(0.0) { sum, record in
            sum + (record.durationInHours)
        }

        // 按分類統計
        var recordsByCategory: [String: Double] = [:]
        for record in completedRecords {
            let category = record.category ?? "未分類"
            recordsByCategory[category, default: 0] += record.durationInHours
        }

        // 按日期統計
        var recordsByDate: [Date: Double] = [:]
        let calendar = Calendar.current
        for record in completedRecords {
            let dateKey = calendar.startOfDay(for: record.clockInTime)
            recordsByDate[dateKey, default: 0] += record.durationInHours
        }

        // 計算平均每日工時
        let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let averageHoursPerDay = totalHours / Double(max(daysDiff, 1))

        return WorkStatistics(
            totalHours: totalHours,
            totalRecords: completedRecords.count,
            averageHoursPerDay: averageHoursPerDay,
            recordsByCategory: recordsByCategory,
            recordsByDate: recordsByDate
        )
    }

    /// 刪除打卡記錄
    func deleteClockRecord(recordId: String) async throws {
        try await db.collection("clockRecords").document(recordId).delete()
        print("✅ Clock record deleted: \(recordId)")
    }

    /// 更新打卡記錄
    func updateClockRecord(
        recordId: String,
        workDescription: String? = nil,
        location: String? = nil,
        category: String? = nil
    ) async throws {
        var updates: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]

        if let description = workDescription {
            updates["workDescription"] = description
        }
        if let location = location {
            updates["location"] = location
        }
        if let category = category {
            updates["category"] = category
        }

        try await db.collection("clockRecords").document(recordId).updateData(updates)
        print("✅ Clock record updated: \(recordId)")
    }
}
