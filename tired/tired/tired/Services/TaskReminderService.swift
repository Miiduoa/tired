import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import UserNotifications

/// 任务提醒服务
class TaskReminderService: ObservableObject {
    private let db = FirebaseManager.shared.db
    private let taskService = TaskService()

    // MARK: - Fetch Reminders

    /// 获取任务的所有提醒
    func fetchReminders(for taskId: String) -> AnyPublisher<[TaskReminder], Error> {
        let subject = PassthroughSubject<[TaskReminder], Error>()

        db.collection("taskReminders")
            .whereField("taskId", isEqualTo: taskId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let reminders = documents.compactMap { doc -> TaskReminder? in
                    try? doc.data(as: TaskReminder.self)
                }

                subject.send(reminders)
            }

        return subject.eraseToAnyPublisher()
    }

    /// 获取用户的所有待发送提醒
    func fetchPendingReminders(userId: String) -> AnyPublisher<[TaskReminder], Error> {
        let subject = PassthroughSubject<[TaskReminder], Error>()

        db.collection("taskReminders")
            .whereField("userId", isEqualTo: userId)
            .whereField("isEnabled", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let reminders = documents.compactMap { doc -> TaskReminder? in
                    try? doc.data(as: TaskReminder.self)
                }

                subject.send(reminders)
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Create/Update/Delete Reminders

    /// 创建提醒
    func createReminder(_ reminder: TaskReminder) async throws {
        var newReminder = reminder
        newReminder.createdAt = Date()
        newReminder.updatedAt = Date()

        _ = try db.collection("taskReminders").addDocument(from: newReminder)

        // 安排本地通知
        if newReminder.isEnabled {
            try await scheduleLocalNotifications(for: reminder)
        }
    }

    /// 更新提醒
    func updateReminder(_ reminder: TaskReminder) async throws {
        guard let id = reminder.id else {
            throw NSError(domain: "TaskReminderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reminder ID is missing"])
        }

        var updatedReminder = reminder
        updatedReminder.updatedAt = Date()

        try db.collection("taskReminders").document(id).setData(from: updatedReminder)

        // 重新安排通知
        if updatedReminder.isEnabled {
            // 先移除旧通知
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            // 创建新通知
            try await scheduleLocalNotifications(for: updatedReminder)
        } else {
            // 移除通知
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
    }

    /// 删除提醒
    func deleteReminder(id: String) async throws {
        try await db.collection("taskReminders").document(id).delete()

        // 移除对应的本地通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Reminder Checking and Sending

    /// 检查并发送应该触发的提醒（应在后台定期运行）
    @MainActor
    func checkAndSendReminders() async {
        let reminders = try? await fetchPendingRemindersOnce()

        for reminder in reminders ?? [] {
            do {
                guard reminder.id != nil else { continue }
                let shouldSend = try await shouldSendReminder(reminder)

                if shouldSend {
                    try await sendReminder(reminder)
                    try await updateReminderSentTime(reminder.id ?? "", sentAt: Date())
                }
            } catch {
                print("❌ Error processing reminder: \(error)")
            }
        }
    }

    /// 获取一次待发送的提醒（非监听版本）
    private func fetchPendingRemindersOnce() async throws -> [TaskReminder] {
        let snapshot = try await db.collection("taskReminders")
            .whereField("isEnabled", isEqualTo: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: TaskReminder.self)
        }
    }

    // MARK: - Reminder Trigger Checking

    /// 检查提醒是否应该被发送
    private func shouldSendReminder(_ reminder: TaskReminder) async throws -> Bool {
        guard let taskDoc = try? await db.collection("tasks").document(reminder.taskId).getDocument(),
              let task = try? taskDoc.data(as: Task.self) else {
            return false
        }

        // 如果任务已完成，不发送提醒
        if task.isDone {
            return false
        }

        let now = Date()
        let lastSentWindow: TimeInterval = 5 * 60  // 5 分钟内的重复提醒会被忽略

        switch reminder.type {
        case .beforeStart:
            guard let plannedDate = task.plannedDate else { return false }

            let triggerTime = plannedDate.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
            let shouldSend = now >= triggerTime && now < plannedDate

            // 检查是否已在这个窗口内发送过
            if shouldSend, let lastSent = reminder.lastSentAt,
               now.timeIntervalSince(lastSent) < lastSentWindow {
                return false
            }

            return shouldSend

        case .beforeDeadline:
            guard let deadline = task.deadlineAt else { return false }

            let triggerTime = deadline.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
            let shouldSend = now >= triggerTime && now < deadline

            // 检查重复发送
            if shouldSend, let lastSent = reminder.lastSentAt,
               now.timeIntervalSince(lastSent) < lastSentWindow {
                return false
            }

            return shouldSend

        case .atStartTime:
            guard let plannedDate = task.plannedDate else { return false }

            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(plannedDate)

            // 检查是否已在今天发送过
            if let lastSent = reminder.lastSentAt {
                let isAlreadySentToday = calendar.isDateInToday(lastSent)
                return isToday && !isAlreadySentToday
            }

            return isToday

        case .oneDayBefore:
            guard let deadline = task.deadlineAt else { return false }

            let calendar = Calendar.current
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
                print("❌ Error: Could not calculate tomorrow's date.")
                return false
            }
            let isTomorrowDeadline = calendar.isDate(deadline, inSameDayAs: tomorrow)

            // 检查是否已在今天发送过
            if let lastSent = reminder.lastSentAt {
                let isAlreadySentToday = calendar.isDateInToday(lastSent)
                return isTomorrowDeadline && !isAlreadySentToday
            }

            return isTomorrowDeadline

        case .custom:
            // 自定义提醒需要在创建时指定 nextTriggerAt
            if let nextTrigger = reminder.nextTriggerAt,
               now >= nextTrigger {
                return true
            }
            return false
        }
    }

    // MARK: - Sending Notifications

    /// 发送提醒通知
    private func sendReminder(_ reminder: TaskReminder) async throws {
        guard let taskId = reminder.id else { return }

        let taskDoc = try await db.collection("tasks").document(reminder.taskId).getDocument()
        guard let task = try? taskDoc.data(as: Task.self) else { return }

        let notification = ReminderNotification(
            taskTitle: task.title,
            reminderType: reminder.type,
            minutesBefore: reminder.minutesBefore,
            taskId: taskId
        )

        // 根据通知方式发送
        switch reminder.notificationMethod {
        case .push, .all:
            try await sendPushNotification(notification, reminderId: reminder.id ?? "")

        case .email:
            try await sendEmailNotification(notification)

        case .inApp:
            try await sendInAppNotification(notification)
        }
    }

    /// 发送 Push 通知
    private func sendPushNotification(_ notification: ReminderNotification, reminderId: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.notificationTitle
        content.body = notification.notificationBody
        content.sound = .default
        
        let badgeCount = await nextBadgeCount()
        content.badge = NSNumber(value: badgeCount)
        await applyBadgeCount(badgeCount)

        // 用户交互数据
        content.userInfo = [
            "taskId": notification.taskId,
            "reminderId": reminderId
        ]

        // 立即发送（1 秒后）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    /// 发送邮件通知（需要后端支持）
    private func sendEmailNotification(_ notification: ReminderNotification) async throws {
        // 这会通过 Cloud Function 调用 Firestore 中存储的邮件发送逻辑
        // 为了简化，这里只记录日志
        print("📧 邮件通知: \(notification.notificationTitle) - \(notification.notificationBody)")
    }

    /// 发送应用内通知
    private func sendInAppNotification(_ notification: ReminderNotification) async throws {
        // 这会通过 App 内的通知系统显示
        // 可以使用 @EnvironmentObject 发布 Notification
        NotificationCenter.default.post(
            name: NSNotification.Name("TaskReminderNotification"),
            object: nil,
            userInfo: [
                "title": notification.notificationTitle,
                "body": notification.notificationBody,
                "taskId": notification.taskId
            ]
        )
    }

    // MARK: - Local Notification Scheduling

    /// 为提醒安排本地通知
    private func scheduleLocalNotifications(for reminder: TaskReminder) async throws {
        guard let taskDoc = try? await db.collection("tasks").document(reminder.taskId).getDocument(),
              let task = try? taskDoc.data(as: Task.self),
              !task.isDone else {
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        let badgeCount = await nextBadgeCount()
        content.badge = NSNumber(value: badgeCount)
        await applyBadgeCount(badgeCount)

        var triggerDate: Date?

        switch reminder.type {
        case .beforeStart:
            if let plannedDate = task.plannedDate {
                triggerDate = plannedDate.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
                content.title = "📌 任务即将开始"
                content.body = "\"\(task.title)\" 将在 \(reminder.minutesBefore) 分钟后开始"
            }

        case .beforeDeadline:
            if let deadline = task.deadlineAt {
                triggerDate = deadline.addingTimeInterval(TimeInterval(-reminder.minutesBefore * 60))
                content.title = "⏰ 任务即将截止"
                content.body = "\"\(task.title)\" 还有 \(reminder.minutesBefore) 分钟截止"
            }

        case .atStartTime:
            if let plannedDate = task.plannedDate {
                triggerDate = plannedDate
                content.title = "▶️ 现在开始任务"
                content.body = task.title
            }

        case .oneDayBefore:
            if let deadline = task.deadlineAt {
                let calendar = Calendar.current
                let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: deadline) ?? deadline
                triggerDate = calendar.startOfDay(for: oneDayBefore).addingTimeInterval(9 * 60 * 60)  // 早上 9 点
                content.title = "📅 任务提醒"
                content.body = "\"\(task.title)\" 明天截止"
            }

        case .custom:
            triggerDate = reminder.nextTriggerAt
            content.title = "🔔 任务提醒"
            content.body = task.title
        }

        // 如果触发时间有效，安排通知
        if let triggerDate = triggerDate, triggerDate > Date() {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id ?? UUID().uuidString, content: content, trigger: trigger)

            try await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Badge Handling

    private func nextBadgeCount() async -> Int {
        async let delivered = deliveredBadgeMax()
        async let pending = pendingBadgeMax()
        let currentMax = max(await delivered, await pending)
        return currentMax + 1
    }

    private func applyBadgeCount(_ badgeCount: Int) async {
        guard #available(iOS 16.0, *) else { return }

        do {
            try await UNUserNotificationCenter.current().setBadgeCount(badgeCount)
        } catch {
            print("Failed to set badge count: \(error.localizedDescription)")
        }
    }

    private func deliveredBadgeMax() async -> Int {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                let maxBadge = notifications.compactMap { $0.request.content.badge?.intValue }.max() ?? 0
                continuation.resume(returning: maxBadge)
            }
        }
    }

    private func pendingBadgeMax() async -> Int {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let maxBadge = requests.compactMap { $0.content.badge?.intValue }.max() ?? 0
                continuation.resume(returning: maxBadge)
            }
        }
    }

    // MARK: - Helper Methods

    /// 更新提醒的最后发送时间
    private func updateReminderSentTime(_ reminderId: String, sentAt: Date) async throws {
        try await db.collection("taskReminders").document(reminderId).updateData([
            "lastSentAt": Timestamp(date: sentAt),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// 请求用户允许发送通知
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
}
