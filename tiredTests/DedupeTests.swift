import XCTest
@testable import tired

final class DedupeTests: XCTestCase {
    struct Item: Deduplicable, InboxItemLike, Equatable {
        let key: String
        let isUrgent: Bool
        let deadline: Date?
        var dedupeKey: String { key }
    }
    
    func testKeepsUrgentOverNonUrgent() {
        let now = Date()
        let a = Item(key: "k", isUrgent: false, deadline: now.addingTimeInterval(3600))
        let b = Item(key: "k", isUrgent: true, deadline: now.addingTimeInterval(7200))
        let deduped = [a, b].deduped()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.isUrgent, true)
    }

    func testKeepsEarlierDeadlineWhenBothUrgent() {
        let now = Date()
        let a = Item(key: "k", isUrgent: true, deadline: now.addingTimeInterval(7200))
        let b = Item(key: "k", isUrgent: true, deadline: now.addingTimeInterval(3600))
        let deduped = [a, b].deduped()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.deadline, b.deadline)
    }

    func testKeepsFirstWhenNoSpecialRuleApplies() {
        struct Simple: Deduplicable, Equatable {
            let key: String
            var dedupeKey: String { key }
        }
        let a = Simple(key: "id")
        let b = Simple(key: "id")
        let deduped = [a, b].deduped()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.key, "id")
    }
}

