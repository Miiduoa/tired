import Testing
@testable import tired

@MainActor
struct AIServiceTests {
    @Test func testBroadcastDraftGeneration() async throws {
        let aiService = AIService.shared
        
        let drafts = try await aiService.generateBroadcastDraft(
            topic: "期中考試",
            audience: "全體同學",
            tone: .formal,
            includeDeadline: true,
            deadline: Date().addingTimeInterval(86400 * 7)
        )
        
        #expect(drafts.count > 0, "應該生成至少一個草稿")
        
        for draft in drafts {
            #expect(!draft.title.isEmpty, "標題不應為空")
            #expect(!draft.body.isEmpty, "內容不應為空")
            #expect(draft.body.contains("期中考試"), "內容應包含主題")
        }
    }
    
    @Test func testSummarization() async throws {
        let aiService = AIService.shared
        
        let longText = """
        今天的會議討論了多個重要議題。首先，我們決定將產品發佈日期推遲到下個月。
        其次，團隊同意增加兩名新成員以加快開發進度。
        最後，我們確認了新的市場策略，將重點放在年輕用戶群體上。
        """
        
        let summary = try await aiService.summarize(text: longText, maxLength: 100)
        
        #expect(!summary.isEmpty, "摘要不應為空")
        #expect(summary.count <= 120, "摘要長度應小於指定長度")
    }
    
    @Test func testSentimentAnalysisPositive() async throws {
        let aiService = AIService.shared
        
        let result = try await aiService.analyzeSentiment(text: "今天真是太棒了！我完成了所有工作，感覺很開心。")
        #expect(result.emotion == .positive, "應該識別為正面情緒")
    }
    
    @Test func testSentimentAnalysisNegative() async throws {
        let aiService = AIService.shared
        
        let result = try await aiService.analyzeSentiment(text: "今天真是糟糕透了，什麼都不順利。")
        #expect(result.emotion == .negative, "應該識別為負面情緒")
    }
    
    @Test func testCBTNudge() async throws {
        let aiService = AIService.shared
        
        let nudge = try await aiService.generateCBTNudge(
            situation: "考試失敗",
            emotion: .negative
        )
        
        #expect(!nudge.reframingQuestions.isEmpty, "應該生成重構問題")
        #expect(!nudge.suggestedAction.isEmpty, "應該建議行動")
        #expect(nudge.estimatedTime > 0, "應該有預估時間")
    }
}

@MainActor
struct ProfileVisibilityServiceTests {
    @Test func testVisibilityModePublic() async throws {
        let service = ProfileVisibilityService.shared
        
        let field = ProfileField(
            id: "test_field",
            key: "displayName",
            type: .text,
            value: .string("測試用戶"),
            visibility: Visibility(mode: .public, groups: nil, orgs: nil, listIds: nil, expiresAt: nil),
            scoped: nil,
            updatedAt: Date(),
            version: 1
        )
        
        let isVisible = service.isVisible(
            field: field,
            viewer: "viewer_123",
            ownerGroups: [],
            viewerGroups: [],
            ownerOrgs: [],
            viewerOrgs: [],
            friendIds: []
        )
        
        #expect(isVisible, "公開欄位對所有人可見")
    }
    
    @Test func testVisibilityModePrivate() async throws {
        let service = ProfileVisibilityService.shared
        
        let field = ProfileField(
            id: "test_field",
            key: "studentId",
            type: .text,
            value: .string("123456"),
            visibility: Visibility(mode: .private, groups: nil, orgs: nil, listIds: nil, expiresAt: nil),
            scoped: nil,
            updatedAt: Date(),
            version: 1
        )
        
        let isVisible = service.isVisible(
            field: field,
            viewer: "viewer_123",
            ownerGroups: [],
            viewerGroups: [],
            ownerOrgs: [],
            viewerOrgs: [],
            friendIds: []
        )
        
        #expect(!isVisible, "私密欄位對所有人不可見")
    }
    
    @Test func testVisibilityModeFriends() async throws {
        let service = ProfileVisibilityService.shared
        
        let field = ProfileField(
            id: "test_field",
            key: "bio",
            type: .text,
            value: .string("這是我的簡介"),
            visibility: Visibility(mode: .friends, groups: nil, orgs: nil, listIds: nil, expiresAt: nil),
            scoped: nil,
            updatedAt: Date(),
            version: 1
        )
        
        // 測試好友可見
        let isFriendVisible = service.isVisible(
            field: field,
            viewer: "friend_123",
            ownerGroups: [],
            viewerGroups: [],
            ownerOrgs: [],
            viewerOrgs: [],
            friendIds: ["friend_123", "friend_456"]
        )
        
        #expect(isFriendVisible, "好友應該可見")
        
        // 測試非好友不可見
        let isNonFriendVisible = service.isVisible(
            field: field,
            viewer: "stranger_789",
            ownerGroups: [],
            viewerGroups: [],
            ownerOrgs: [],
            viewerOrgs: [],
            friendIds: ["friend_123", "friend_456"]
        )
        
        #expect(!isNonFriendVisible, "非好友不應該可見")
    }
}

struct RolePermissionsTests {
    @Test func testOwnerPermissions() {
        #expect(RolePermissions.canManageMembers(.owner), "Owner 應該可以管理成員")
        #expect(RolePermissions.canPublishBroadcast(.owner), "Owner 應該可以發布公告")
        #expect(RolePermissions.canViewInsights(.owner), "Owner 應該可以查看分析")
    }
    
    @Test func testAdminPermissions() {
        #expect(RolePermissions.canManageMembers(.admin), "Admin 應該可以管理成員")
        #expect(RolePermissions.canPublishBroadcast(.admin), "Admin 應該可以發布公告")
    }
    
    @Test func testManagerPermissions() {
        #expect(!RolePermissions.canManageMembers(.manager), "Manager 不應該可以管理成員")
        #expect(!RolePermissions.canPublishBroadcast(.manager), "Manager 不應該可以發布公告")
        #expect(RolePermissions.canManageAttendance(.manager), "Manager 應該可以管理出勤")
    }
    
    @Test func testMemberPermissions() {
        #expect(!RolePermissions.canManageMembers(.member), "Member 不應該可以管理成員")
        #expect(!RolePermissions.canPublishBroadcast(.member), "Member 不應該可以發布公告")
        #expect(RolePermissions.canViewAttendance(.member), "Member 應該可以查看出勤")
    }
    
    @Test func testGuestPermissions() {
        #expect(!RolePermissions.canManageMembers(.guest), "Guest 不應該可以管理成員")
        #expect(!RolePermissions.canChat(.guest), "Guest 不應該可以聊天")
    }
}

struct ModelTests {
    @Test func testTenantTypeDisplayName() {
        #expect(TenantType.school.displayName == "學校")
        #expect(TenantType.company.displayName == "企業")
        #expect(TenantType.community.displayName == "社群")
        #expect(TenantType.esg.displayName == "ESG")
    }
    
    @Test func testMembershipRoleDisplayName() {
        #expect(TenantMembership.Role.owner.displayName == "擁有者")
        #expect(TenantMembership.Role.admin.displayName == "管理員")
        #expect(TenantMembership.Role.manager.displayName == "經理")
        #expect(TenantMembership.Role.member.displayName == "成員")
        #expect(TenantMembership.Role.guest.displayName == "訪客")
    }
}

@MainActor
struct SearchServiceTests {
    @Test func testSearchHistoryManagement() {
        let searchService = EnhancedSearchService.shared
        
        // 清空歷史
        searchService.clearHistory()
        #expect(searchService.searchHistory.count == 0, "歷史應為空")
    }
}

