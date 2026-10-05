import XCTest
@testable import PlanningCore

final class WeeklyPlannerTests: XCTestCase {
    func testHighPriorityTaskIsScheduledEarlier() {
        let planner = WeeklyPlanner(
            days: 3,
            dailyCapacityMinutes: 120
        )

        let result = planner.plan(tasks: [
            PlanningTask(
                id: "low",
                durationMinutes: 60,
                priority: .low
            ),
            PlanningTask(
                id: "high",
                durationMinutes: 60,
                priority: .high
            )
        ])

        XCTAssertEqual(result.assignments["high"], 0)
        XCTAssertNotNil(result.assignments["low"])
    }

    func testDeadlineIsNeverExceeded() {
        let planner = WeeklyPlanner(
            days: 4,
            dailyCapacityMinutes: 60
        )

        let result = planner.plan(
            tasks: [
                PlanningTask(
                    id: "due-tomorrow",
                    durationMinutes: 60,
                    priority: .medium,
                    deadlineDay: 1
                )
            ],
            busyBlocks: [
                BusyBlock(day: 0, durationMinutes: 60)
            ]
        )

        XCTAssertEqual(
            result.assignments["due-tomorrow"],
            1
        )
    }

    func testBusyBlockConsumesCapacity() {
        let planner = WeeklyPlanner(
            days: 2,
            dailyCapacityMinutes: 120
        )

        let result = planner.plan(
            tasks: [
                PlanningTask(
                    id: "task",
                    durationMinutes: 90,
                    priority: .medium
                )
            ],
            busyBlocks: [
                BusyBlock(day: 0, durationMinutes: 60)
            ]
        )

        XCTAssertEqual(result.assignments["task"], 1)
        XCTAssertEqual(result.dayLoad, [60, 90])
    }

    func testLockedTaskKeepsItsDay() {
        let planner = WeeklyPlanner(
            days: 3,
            dailyCapacityMinutes: 120
        )

        let result = planner.plan(tasks: [
            PlanningTask(
                id: "locked",
                durationMinutes: 80,
                priority: .low,
                lockedDay: 2
            )
        ])

        XCTAssertEqual(result.assignments["locked"], 2)
        XCTAssertEqual(result.dayLoad[2], 80)
    }

    func testTaskIsSkippedWhenNoDayHasCapacity() {
        let planner = WeeklyPlanner(
            days: 2,
            dailyCapacityMinutes: 60
        )

        let result = planner.plan(
            tasks: [
                PlanningTask(
                    id: "large",
                    durationMinutes: 90,
                    priority: .high
                )
            ]
        )

        XCTAssertNil(result.assignments["large"])
        XCTAssertEqual(
            result.skipped["large"],
            .noCapacity
        )
    }

    func testDoneTaskDoesNotConsumeCapacity() {
        let planner = WeeklyPlanner(
            days: 1,
            dailyCapacityMinutes: 60
        )

        let result = planner.plan(tasks: [
            PlanningTask(
                id: "done",
                durationMinutes: 60,
                priority: .high,
                isDone: true
            ),
            PlanningTask(
                id: "open",
                durationMinutes: 60,
                priority: .medium
            )
        ])

        XCTAssertNil(result.assignments["done"])
        XCTAssertEqual(result.assignments["open"], 0)
        XCTAssertEqual(result.dayLoad, [60])
    }
}
