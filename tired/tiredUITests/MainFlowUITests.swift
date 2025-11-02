import XCTest

final class MainFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAutoLoginShowsLanding() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-autologin"]
        app.launch()
        // 允許首頁或動態做為預設落點
        let ok = app.staticTexts["首頁"].waitForExistence(timeout: 3) || app.staticTexts["動態"].waitForExistence(timeout: 3)
        XCTAssertTrue(ok, "應顯示首頁或動態")
    }

    @MainActor
    func testNavigateTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-autologin"]
        app.launch()

        let tabBar = app.tabBars.firstMatch

        // 公告
        if tabBar.buttons["公告"].exists { tabBar.buttons["公告"].tap() }
        XCTAssertTrue(app.staticTexts["公告"].waitForExistence(timeout: 5), "應顯示公告頁")

        // 收件匣
        if tabBar.buttons["收件匣"].exists { tabBar.buttons["收件匣"].tap() }
        XCTAssertTrue(app.staticTexts["收件匣"].waitForExistence(timeout: 5), "應顯示收件匣頁")

        // 出勤
        if tabBar.buttons["出勤"].exists { tabBar.buttons["出勤"].tap() }
        XCTAssertTrue(app.staticTexts["10 秒點名"].waitForExistence(timeout: 5), "應顯示出勤頁")
    }
}
