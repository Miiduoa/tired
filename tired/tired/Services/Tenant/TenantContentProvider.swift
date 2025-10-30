import Foundation
import Combine

enum TenantContentProvider {
    static func demoMemberships(for user: User) -> [TenantMembership] {
        let demoTenant = Tenant(
            id: "demo-campus",
            name: "北城大學資訊管理系",
            type: .school,
            metadata: [
                "module.activities.title": "課務活動",
                "module.insights.title": "出勤分析"
            ]
        )
        let pack = CapabilityPack.defaultPack(for: .school)
        let configuration = TenantConfiguration(
            id: "demo-config",
            adapter: .firebase,
            featureFlags: TenantConfiguration.FeatureFlags(enabledModules: pack.enabledModules)
        )
        return [TenantMembership(id: demoTenant.id, tenant: demoTenant, role: .manager, capabilityPack: pack, configuration: configuration)]
    }
    
    static func packByIdentifier(_ id: String, fallbackType: TenantType) -> CapabilityPack? {
        switch id {
        case "pack-school": return CapabilityPack.defaultPack(for: .school)
        case "pack-company": return CapabilityPack.defaultPack(for: .company)
        case "pack-community": return CapabilityPack.defaultPack(for: .community)
        case "pack-esg": return CapabilityPack.defaultPack(for: .esg)
        default:
            return CapabilityPack.defaultPack(for: fallbackType)
        }
    }
    
    static func broadcasts(for membership: TenantMembership) -> [BroadcastListItem] {
        let baseId = membership.id
        return [
            BroadcastListItem(
                id: "\(baseId)-midterm",
                title: "系辦公告：期中考換教室",
                body: "資訊管理系三年級期中考統一移至 H501，請於 11/12 08:30 前完成確認。",
                deadline: Date().addingTimeInterval(60 * 60 * 24),
                requiresAck: true,
                acked: false,
                eventId: "\(baseId)-midterm"
            ),
            BroadcastListItem(
                id: "\(baseId)-rollcall",
                title: "10 秒點名提醒",
                body: "10:10 開始點名，請在教室掃描 QR 碼或啟用近場感應。",
                deadline: Date().addingTimeInterval(60 * 15),
                requiresAck: false,
                acked: false,
                eventId: nil
            )
        ]
    }
    
    static func activities(for membership: TenantMembership) -> [ActivityListItem] {
        [
            ActivityListItem(kind: .broadcast, title: "緊急廣播", subtitle: "下午停電，請提早備份資料", timestamp: .now.addingTimeInterval(-3600)),
            ActivityListItem(kind: .rollcall, title: "資料庫課程點名完成", subtitle: "異常：2", timestamp: .now.addingTimeInterval(-5400)),
            ActivityListItem(kind: .clock, title: "外勤簽到成功", subtitle: "高雄營運據點", timestamp: .now.addingTimeInterval(-7200)),
            ActivityListItem(kind: .esg, title: "碳排挑戰進度", subtitle: "本週節能達成 82%", timestamp: .now.addingTimeInterval(-10800))
        ]
    }
    
    static func inbox(for membership: TenantMembership) -> [InboxItem] {
        [
            InboxItem(
                id: "\(membership.id)-ack",
                kind: .ack,
                title: "需回條：停課公告",
                subtitle: "請回覆『已知悉』",
                deadline: Date().addingTimeInterval(60 * 60 * 4),
                isUrgent: true,
                priority: .urgent,
                eventId: "\(membership.id)-ack"
            ),
            InboxItem(
                id: "\(membership.id)-rollcall",
                kind: .rollcall,
                title: "10 秒點名",
                subtitle: "資料庫 H501，即將結束",
                deadline: Date().addingTimeInterval(60 * 8),
                isUrgent: true,
                priority: .high,
                eventId: nil
            ),
            InboxItem(
                id: "\(membership.id)-assignment",
                kind: .assignment,
                title: "作業提醒：資料探勘小組報告",
                subtitle: "請於 11/15 23:59 前上傳",
                deadline: Date().addingTimeInterval(60 * 60 * 24 * 2),
                isUrgent: false,
                priority: .normal,
                eventId: nil
            )
        ]
    }
    
    static func clockRecords(for membership: TenantMembership) -> [ClockRecordItem] {
        [
            ClockRecordItem(id: "\(membership.id)-clock-1", site: "台北信義總部", time: .now.addingTimeInterval(-900), status: .ok),
            ClockRecordItem(id: "\(membership.id)-clock-2", site: "新竹研發中心", time: .now.addingTimeInterval(-3600), status: .ok),
            ClockRecordItem(id: "\(membership.id)-clock-3", site: "高雄維運據點", time: .now.addingTimeInterval(-5400), status: .exception)
        ]
    }
    
    static func attendanceSnapshot(for membership: TenantMembership) -> AttendanceSnapshot {
        let stats = AttendanceStats(attended: 45, absent: 3, late: 2, total: 50)
        return AttendanceSnapshot(
            courseName: membership.tenant.type == .company ? "部門出勤" : "AI 應用導論",
            attendanceTime: Date().addingTimeInterval(60 * 10),
            validDuration: 45,
            stats: stats,
            personalRecords: [
                AttendanceRecord(courseName: "AI 應用導論", date: Date().addingTimeInterval(-86400), status: .present),
                AttendanceRecord(courseName: "資料庫系統", date: Date().addingTimeInterval(-172800), status: .late),
                AttendanceRecord(courseName: "演算法", date: Date().addingTimeInterval(-259200), status: .present)
            ]
        )
    }
    
    static func esgSummary(for membership: TenantMembership) -> ESGSummary {
        ESGSummary(
            progress: membership.metadata["esg.progress"] ?? "82%",
            monthlyReduction: membership.metadata["esg.monthlyReduction"] ?? "-12%",
            records: [
                ESGRecordItem(id: "\(membership.id)-esg-upload", title: "水電帳單上傳", subtitle: "OCR 完成，待確認", timestamp: Date().addingTimeInterval(-3600)),
                ESGRecordItem(id: "\(membership.id)-esg-report", title: "碳排月報", subtitle: "10 月報告已生成", timestamp: Date().addingTimeInterval(-86400 * 2)),
                ESGRecordItem(id: "\(membership.id)-esg-challenge", title: "節能挑戰", subtitle: "本週達成 75%", timestamp: Date().addingTimeInterval(-86400 * 4))
            ]
        )
    }
    
    static func insights(for membership: TenantMembership) -> [InsightSection] {
        [
            InsightSection(
                id: "attendance",
                title: "出勤",
                entries: [
                    InsightEntry(id: "\(membership.id)-insight-attendanceRate", category: "attendance", title: "本月平均到課率", value: membership.metadata["insights.attendanceRate"] ?? "92%", trend: "↑ 4%"),
                    InsightEntry(id: "\(membership.id)-insight-hotspot", category: "attendance", title: "遲到熱區", value: membership.metadata["insights.hotspot"] ?? "星期一 08:10", trend: "提醒教學助理")
                ]
            ),
            InsightSection(
                id: "esg",
                title: "ESG",
                entries: [
                    InsightEntry(id: "\(membership.id)-insight-carbon", category: "esg", title: "碳排趨勢", value: membership.metadata["insights.carbon"] ?? "-8% MoM", trend: "節能計畫生效")
                ]
            ),
            InsightSection(
                id: "engagement",
                title: "互動",
                entries: [
                    InsightEntry(id: "\(membership.id)-insight-ack", category: "engagement", title: "公告回條率", value: membership.metadata["insights.ackRate"] ?? "96%", trend: "↑ 2%"),
                    InsightEntry(id: "\(membership.id)-insight-inbox", category: "engagement", title: "收件匣待處理", value: "\(inbox(for: membership).count) 件", trend: "專注高優先處理")
                ]
            )
        ]
    }
}
