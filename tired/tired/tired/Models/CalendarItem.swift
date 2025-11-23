import Foundation
import SwiftUI

/// 在日曆上顯示的統一項目，可以是一個活動或一個任務
struct CalendarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let type: ItemType
    let organizationName: String
    let organizationId: String
    
    // 根據類型顯示不同的顏色或圖標
    var tintColor: Color {
        switch type {
        case .event:
            return .blue
        case .task:
            return .orange
        }
    }
    
    var iconName: String {
        switch type {
        case .event:
            return "calendar"
        case .task:
            return "checklist"
        }
    }

    enum ItemType: String {
        case event = "活動"
        case task = "任務"
    }
}

// MARK: - Initializers
extension CalendarItem {
    /// 從 Event 初始化
    init(from event: Event, organization: Organization?) {
        self.id = event.id ?? UUID().uuidString
        self.title = event.title
        self.date = event.startAt
        self.type = .event
        self.organizationName = organization?.name ?? "未知組織"
        self.organizationId = event.organizationId
    }
    
    /// 從 Task 初始化
    init(from task: Task, organization: Organization?) {
        self.id = task.id ?? UUID().uuidString
        self.title = task.title
        self.date = task.deadlineAt ?? task.plannedDate ?? Date() // 優先使用截止日期，其次是計劃日期
        self.type = .task
        self.organizationName = organization?.name ?? "未知組織"
        self.organizationId = task.sourceOrgId ?? ""
    }
}
