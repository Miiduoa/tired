import XCTest
@testable import tired

@MainActor
final class FirestoreDataServiceTests: XCTestCase {
    
    var service: FirestoreDataService!
    
    override func setUpWithError() throws {
        service = FirestoreDataService.shared
    }
    
    override func tearDownWithError() throws {
        service = nil
    }
    
    // MARK: - User Profile Tests
    
    func testFetchUserProfile() async throws {
        // Given
        let userId = "test-user-123"
        
        // When
        let profile = try await service.fetchUserProfile(userId: userId)
        
        // Then
        XCTAssertNotNil(profile)
    }
    
    func testUpdateUserProfile() async throws {
        // Given
        let userId = "test-user-123"
        let profile = UserProfile(
            displayName: "Test User",
            bio: "Test bio",
            photoURL: nil,
            coverPhotoURL: nil,
            interests: ["coding", "music"],
            location: "Taipei"
        )
        
        // When & Then
        try await service.updateUserProfile(userId: userId, profile: profile)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    // MARK: - Tenant Tests
    
    func testFetchTenant() async throws {
        // Given
        let tenantId = "test-tenant-123"
        
        // When
        let tenant = try await service.fetchTenant(tenantId: tenantId)
        
        // Then
        // 可能返回 nil（如果不存在），但不應拋出錯誤
        if let tenant = tenant {
            XCTAssertFalse(tenant.name.isEmpty)
        }
    }
    
    // MARK: - Posts Tests
    
    func testCreatePost() async throws {
        // Given
        let post = Post(
            id: UUID().uuidString,
            content: "Test post content",
            authorId: "test-user-123",
            authorName: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            likeCount: 0,
            commentCount: 0,
            shareCount: 0
        )
        
        // When & Then
        try await service.createPost(post: post)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    func testLikePost() async throws {
        // Given
        let postId = "test-post-123"
        let userId = "test-user-123"
        
        // When & Then
        try await service.likePost(postId: postId, userId: userId)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    // MARK: - Messages Tests
    
    func testSendMessage() async throws {
        // Given
        let message = Message(
            id: UUID().uuidString,
            conversationId: "test-conversation-123",
            senderId: "test-user-123",
            content: "Test message",
            timestamp: Date(),
            type: .text
        )
        
        // When & Then
        try await service.sendMessage(message: message)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    // MARK: - Attendance Tests
    
    func testCreateAttendanceSession() async throws {
        // Given
        let session = AttendanceSession(
            id: UUID().uuidString,
            tenantId: "test-tenant-123",
            title: "Test Session",
            qrCode: nil,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            createdAt: Date(),
            location: nil
        )
        
        // When & Then
        try await service.createAttendanceSession(session: session)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    func testCheckInAttendance() async throws {
        // Given
        let sessionId = "test-session-123"
        let userId = "test-user-123"
        let location = Location(latitude: 25.0330, longitude: 121.5654)
        
        // When & Then
        try await service.checkInAttendance(sessionId: sessionId, userId: userId, location: location)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    // MARK: - Clock In/Out Tests
    
    func testClockIn() async throws {
        // Given
        let userId = "test-user-123"
        let tenantId = "test-tenant-123"
        let siteId = "test-site-123"
        let location = Location(latitude: 25.0330, longitude: 121.5654)
        
        // When & Then
        try await service.clockIn(userId: userId, tenantId: tenantId, siteId: siteId, location: location)
        // 如果沒有拋出錯誤，則測試通過
    }
    
    // MARK: - ESG Tests
    
    func testCreateESGRecord() async throws {
        // Given
        let record = ESGRecord(
            id: UUID().uuidString,
            tenantId: "test-tenant-123",
            category: "electricity",
            value: 100.0,
            unit: "kWh",
            createdAt: Date(),
            description: "Test ESG record",
            imageURL: nil
        )
        
        // When & Then
        try await service.createESGRecord(record: record)
        // 如果沒有拋出錯誤，則測試通過
    }
}

