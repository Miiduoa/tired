import Foundation
import SwiftUI

struct BroadcastListItem: Identifiable, Codable, Deduplicable {
    let id: String
    let title: String
    let body: String
    let deadline: Date?
    let requiresAck: Bool
    var acked: Bool
    let eventId: String?
    
    var dedupeKey: String { id }
}

struct ActivityListItem: Identifiable, Deduplicable {
    enum Kind: String {
        case broadcast
        case rollcall
        case clock
        case esg
    }
    
    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    let timestamp: Date
    
    var dedupeKey: String {
        "\(kind.rawValue)-\(title)-\(subtitle)"
    }
}

struct ClockRecordItem: Identifiable, Deduplicable, Codable {
    enum Status: String, Codable {
        case ok
        case exception
    }
    
    let id: String
    let site: String
    let time: Date
    let status: Status
    
    var dedupeKey: String {
        "\(site)-\(Int(time.timeIntervalSince1970/60))"
    }
}

struct AttendanceStats: Codable {
    let attended: Int
    let absent: Int
    let late: Int
    let total: Int
}

struct AttendanceRecord: Identifiable, Codable {
    let id = UUID()
    let courseName: String
    let date: Date
    let status: AttendanceStatus
}

enum AttendanceStatus: String, Codable {
    case present
    case absent
    case late
    
    var title: String {
        switch self {
        case .present: return "已簽到"
        case .absent: return "未簽到"
        case .late: return "遲到"
        }
    }
    
    var icon: String {
        switch self {
        case .present: return "checkmark.circle.fill"
        case .absent: return "xmark.circle.fill"
        case .late: return "clock.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .present: return .green
        case .absent: return .red
        case .late: return .orange
        }
    }
}

struct AttendanceSnapshot: Codable {
    let courseName: String
    let attendanceTime: Date
    let validDuration: Int
    let stats: AttendanceStats
    let personalRecords: [AttendanceRecord]
}

struct InboxItem: Identifiable, Hashable, Codable, Deduplicable {
    enum Kind: String, Codable, CaseIterable {
        case ack
        case rollcall
        case clockin
        case assignment
        case esgTask
    }
    
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let deadline: Date?
    let isUrgent: Bool
    let priority: Priority
    let eventId: String?
    
    enum Priority: String, Codable {
        case low
        case normal
        case high
        case urgent
        
        var color: Color {
            switch self {
            case .low: return .labelSecondary
            case .normal: return .primary
            case .high: return .orange
            case .urgent: return .red
            }
        }
    }
    
    var dedupeKey: String {
        if let eid = eventId { return "\(kind.rawValue)-eid-\(eid)" }
        let stamp = deadline?.timeIntervalSince1970 ?? -1
        return "\(kind.rawValue)-\(title)-\(subtitle)-\(stamp)"
    }
}

struct ESGRecordItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let timestamp: Date
}

struct ESGSummary: Codable {
    let progress: String
    let monthlyReduction: String
    let records: [ESGRecordItem]
}

struct InsightEntry: Identifiable, Codable {
    let id: String
    let category: String
    let title: String
    let value: String
    let trend: String
    
    var dedupeKey: String { "\(category)-\(title)-\(value)-\(trend)" }
}

struct InsightSection: Identifiable, Codable {
    let id: String
    let title: String
    let entries: [InsightEntry]
}

