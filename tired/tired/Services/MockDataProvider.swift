import Foundation

/// 提供完整的 Mock 數據，讓 APP 在沒有後端時也能展示完整功能
@MainActor
final class MockDataProvider {
    static let shared = MockDataProvider()
    
    private init() {}
    
    // MARK: - 用戶數據
    
    func mockUsers(count: Int = 10) -> [UserSearchResult] {
        let names = ["張小明", "李小華", "王小美", "陳小強", "林小芳", "黃小龍", "吳小蘭", "劉小青", "鄭小文", "謝小雨"]
        return (0..<min(count, names.count)).map { i in
            UserSearchResult(
                id: "user_\(i)",
                displayName: names[i],
                email: "\(names[i])@tired.app",
                avatarUrl: nil
            )
        }
    }
    
    // MARK: - 公告數據
    
    func mockBroadcasts(count: Int = 5) -> [BroadcastListItem] {
        let titles = [
            "期中考試通知",
            "校慶活動報名",
            "防疫措施更新",
            "圖書館閉館通知",
            "獎學金申請開放"
        ]
        
        let bodies = [
            "下週一至週三進行期中考試，請同學準時到場，攜帶學生證。",
            "校慶將於下月舉行，歡迎同學踴躍報名參加各項活動。",
            "因應疫情變化，全校師生進入教室前請配合測量體溫。",
            "圖書館將於本週六進行系統維護，當日暫停開放。",
            "本學期獎學金申請已開放，請符合資格同學於截止日前提出申請。"
        ]
        
        return (0..<min(count, titles.count)).map { i in
            BroadcastListItem(
                id: "broadcast_\(i)",
                title: titles[i],
                body: bodies[i],
                deadline: Date().addingTimeInterval(TimeInterval(86400 * (i + 1))),
                requiresAck: i % 2 == 0,
                acked: i % 3 == 0,
                eventId: nil
            )
        }
    }
    
    // MARK: - 活動數據
    
    func mockEvents(count: Int = 8) -> [Event] {
        let eventData: [(String, String, Bool)] = [
            ("團隊建立工作坊", "透過各種互動遊戲增進團隊默契", true),
            ("創業講座", "邀請成功創業家分享經驗", true),
            ("音樂會", "學生樂團期末成果發表", false),
            ("運動會", "全校師生運動競賽", true),
            ("畢業典禮", "祝賀畢業生完成學業", false),
            ("校園導覽", "新生入學校園介紹", true),
            ("社團博覽會", "各社團招生展示", false),
            ("期末聚餐", "慶祝學期結束聚餐", true)
        ]
        
        return (0..<min(count, eventData.count)).map { i in
            let data = eventData[i]
            return Event(
                id: "event_\(i)",
                tenantId: "tenant_1",
                title: data.0,
                description: data.1,
                startTime: Date().addingTimeInterval(TimeInterval(86400 * (i + 2))),
                endTime: Date().addingTimeInterval(TimeInterval(86400 * (i + 2) + 7200)),
                location: i % 2 == 0 ? "活動中心" : "體育館",
                requiresRSVP: data.2,
                capacity: i % 2 == 0 ? 100 : nil,
                registeredCount: Int.random(in: 20...80)
            )
        }
    }
    
    // MARK: - 投票數據
    
    func mockPolls(count: Int = 5) -> [Poll] {
        let pollData: [(String, [String], Bool)] = [
            ("下個月團隊活動選擇？", ["登山健行", "密室逃脫", "美食聚會", "運動競賽"], false),
            ("辦公室改善建議（可多選）", ["增加綠植", "改善照明", "升級咖啡機", "添置按摩椅"], true),
            ("最喜歡的社團活動", ["登山社", "音樂社", "程式社", "攝影社"], false),
            ("午餐時間調整", ["11:30-12:30", "12:00-13:00", "12:30-13:30", "維持現狀"], false),
            ("新制服款式選擇", ["款式 A", "款式 B", "款式 C", "維持現有"], false)
        ]
        
        return (0..<min(count, pollData.count)).map { i in
            let data = pollData[i]
            return Poll(
                id: "poll_\(i)",
                tenantId: "tenant_1",
                question: data.0,
                options: data.1,
                allowMultiple: data.2,
                deadline: Date().addingTimeInterval(TimeInterval(86400 * (i + 5))),
                totalVotes: Int.random(in: 30...120),
                userVoted: i % 3 == 0
            )
        }
    }
    
    // MARK: - 文章數據
    
    func mockPosts(count: Int = 10) -> [PostSearchResult] {
        let titles = [
            "如何提升團隊協作效率",
            "遠端工作的最佳實踐",
            "時間管理技巧分享",
            "健康生活習慣養成",
            "專案管理工具推薦",
            "持續學習的重要性",
            "溝通技巧提升方法",
            "創意思考訓練",
            "壓力管理策略",
            "目標設定與達成"
        ]
        
        return (0..<min(count, titles.count)).map { i in
            PostSearchResult(
                id: "post_\(i)",
                summary: titles[i],
                content: "這是關於\(titles[i])的詳細內容說明...",
                authorName: mockUsers()[i % mockUsers().count].displayName,
                createdAt: Date().addingTimeInterval(-TimeInterval(86400 * i)),
                highlights: []
            )
        }
    }
    
    // MARK: - 打卡記錄
    
    func mockClockRecords(count: Int = 7) -> [ClockRecordItem] {
        let sites = ["總部大樓", "研發中心", "營運部門"]
        let calendar = Calendar.current
        
        return (0..<count).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let status: ClockRecordItem.Status = i == 2 ? .exception : .ok
            
            return ClockRecordItem(
                id: "clock_\(i)",
                site: sites[i % sites.count],
                time: date.addingTimeInterval(TimeInterval(9 * 3600)), // 9 AM
                status: status
            )
        }
    }
    
    // MARK: - 出勤記錄
    
    func mockAttendanceRecords(count: Int = 10) -> [AttendanceRecord] {
        let calendar = Calendar.current
        let names = mockUsers().map { $0.displayName }
        
        return (0..<count).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let status: AttendanceRecord.Status
            
            if i % 5 == 0 {
                status = .late
            } else if i % 7 == 0 {
                status = .absent
            } else {
                status = .present
            }
            
            return AttendanceRecord(
                id: "attendance_\(i)",
                userId: "user_\(i % names.count)",
                userName: names[i % names.count],
                sessionId: "session_1",
                timestamp: date.addingTimeInterval(TimeInterval(10 * 3600)), // 10 AM
                status: status
            )
        }
    }
    
    // MARK: - 對話數據
    
    func mockConversations(for userId: String, count: Int = 5) -> [Conversation] {
        let users = mockUsers()
        
        return (0..<min(count, users.count - 1)).map { i in
            let otherUser = users[i + 1]
            let lastMessage = mockMessages()[0]
            
            return Conversation(
                id: "conv_\(i)",
                participantIds: [userId, otherUser.id],
                title: otherUser.displayName,
                lastMessage: lastMessage.content,
                lastMessageTimestamp: lastMessage.timestamp,
                unreadCount: i % 3 == 0 ? Int.random(in: 1...5) : 0
            )
        }
    }
    
    // MARK: - 訊息數據
    
    func mockMessages(count: Int = 20) -> [Message] {
        let messageTexts = [
            "你好，最近還好嗎？",
            "今天的會議記得參加喔",
            "檔案已經上傳到雲端",
            "明天一起吃午餐嗎？",
            "專案進度如何了？",
            "感謝你的幫忙！",
            "收到，了解",
            "等等打給你",
            "報告已經完成了",
            "這個想法不錯",
            "需要協助嗎？",
            "好的，沒問題",
            "辛苦了！",
            "下週見",
            "資料已確認",
            "謝謝提醒",
            "我在路上了",
            "稍後回覆",
            "今天天氣真好",
            "週末愉快"
        ]
        
        return (0..<min(count, messageTexts.count)).map { i in
            Message(
                id: "msg_\(i)",
                conversationId: "conv_1",
                senderId: i % 2 == 0 ? "user_1" : "user_2",
                senderName: i % 2 == 0 ? "我" : "張小明",
                content: messageTexts[i],
                timestamp: Date().addingTimeInterval(-TimeInterval(3600 * i)),
                type: .text
            )
        }
    }
    
    // MARK: - 好友數據
    
    func mockFriends(count: Int = 8) -> [Friend] {
        let users = mockUsers(count: count)
        
        return users.enumerated().map { i, user in
            Friend(
                id: "friend_\(i)",
                user: FriendUser(
                    id: user.id,
                    displayName: user.displayName,
                    photoURL: user.avatarUrl
                ),
                since: Date().addingTimeInterval(-TimeInterval(86400 * (i + 1) * 10))
            )
        }
    }
    
    // MARK: - 好友請求
    
    func mockFriendRequests(count: Int = 3) -> [FriendRequest] {
        let users = mockUsers(count: count)
        
        return users.enumerated().map { i, user in
            FriendRequest(
                id: "req_\(i)",
                from: FriendUser(
                    id: user.id,
                    displayName: user.displayName,
                    photoURL: user.avatarUrl
                ),
                createdAt: Date().addingTimeInterval(-TimeInterval(3600 * (i + 1)))
            )
        }
    }
    
    // MARK: - ESG 記錄
    
    func mockESGRecords(count: Int = 10) -> [ESGRecordItem] {
        let categories = ["電力消耗", "水資源", "廢棄物", "碳排放"]
        let units = ["kWh", "立方公尺", "公斤", "公噸"]
        
        return (0..<count).map { i in
            let categoryIndex = i % categories.count
            return ESGRecordItem(
                id: "esg_\(i)",
                category: categories[categoryIndex],
                value: Double.random(in: 100...1000),
                unit: units[categoryIndex],
                timestamp: Date().addingTimeInterval(-TimeInterval(86400 * i)),
                location: "總部"
            )
        }
    }
    
    // MARK: - 收件箱任務
    
    func mockInboxItems(count: Int = 8) -> [InboxItem] {
        let kinds: [InboxItem.Kind] = [.ack, .rollcall, .clockin, .assignment, .esgTask]
        let priorities: [InboxItem.Priority] = [.low, .normal, .high, .urgent]
        
        let titles = [
            "確認收到會議通知",
            "今日課程點名",
            "上班打卡提醒",
            "專案報告繳交",
            "ESG 數據更新",
            "活動回條確認",
            "出勤異常說明",
            "文件審核"
        ]
        
        let subtitles = [
            "請確認是否收到明天會議通知",
            "10:00 AM 課程即將開始",
            "請於 9:00 前完成打卡",
            "請於今日下班前繳交",
            "請更新本月 ESG 數據",
            "請確認是否參加活動",
            "請說明昨日出勤異常原因",
            "有 3 份文件待審核"
        ]
        
        return (0..<min(count, titles.count)).map { i in
            InboxItem(
                id: "inbox_\(i)",
                kind: kinds[i % kinds.count],
                title: titles[i],
                subtitle: subtitles[i],
                deadline: i % 2 == 0 ? Date().addingTimeInterval(TimeInterval(3600 * (i + 1))) : nil,
                priority: priorities[i % priorities.count]
            )
        }
    }
}

