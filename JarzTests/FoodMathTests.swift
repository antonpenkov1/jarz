import XCTest
@testable import Jarz

/// The food plan contract, pinned by Anton's reference scenario (2026-08-10):
/// income fixes the horizon, overspending pushes the "money returns" day,
/// top-ups cushion today, and ONLY income ever moves the end date.
final class FoodMathTests: XCTestCase {
    private let daily: Decimal = 1000

    private func august(_ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12))!
    }

    private func assertSameDay(_ lhs: Date?, _ rhs: Date, file: StaticString = #filePath, line: UInt = #line) {
        guard let lhs else { return XCTFail("date is nil", file: file, line: line) }
        XCTAssertTrue(Calendar.current.isDate(lhs, inSameDayAs: rhs), file: file, line: line)
    }

    func testReferenceScenario() {
        let today = august(10)

        // Aug 10: income 5000 at 1000/day → fixed until Aug 14.
        let planEnd = FoodMath.extendPlanEnd(current: nil, allocation: 5000, daily: daily, now: today)
        assertSameDay(planEnd, august(14))

        var balance: Decimal = 5000
        var plan = FoodMath.plan(balance: balance, daily: daily, planEnd: planEnd, now: today)!
        XCTAssertEqual(plan.available, 1000)
        XCTAssertFalse(plan.isAhead)

        // Spent 1200 → 800 left, belonging to Aug 11; Aug 12–14 untouched.
        balance -= 1200
        plan = FoodMath.plan(balance: balance, daily: daily, planEnd: planEnd, now: today)!
        XCTAssertTrue(plan.isAhead)
        XCTAssertEqual(plan.available, 800)
        assertSameDay(plan.dayDate, august(11))

        // Spent 900 more → 900 left on Aug 12; 13th and 14th still 1000 each.
        balance -= 900
        plan = FoodMath.plan(balance: balance, daily: daily, planEnd: planEnd, now: today)!
        XCTAssertEqual(plan.available, 900)
        assertSameDay(plan.dayDate, august(12))
        let week = FoodMath.weekAhead(plan: plan, daily: daily, now: today)
        XCTAssertEqual(week.map(\.amount), [0, 0, 900, 1000, 1000])
        XCTAssertEqual(week.map(\.isEaten), [true, true, false, false, false])

        // Money in +4100 covers the hole and leaves 3000 for today (Aug 10).
        balance += 4100
        plan = FoodMath.plan(balance: balance, daily: daily, planEnd: planEnd, now: today)!
        XCTAssertFalse(plan.isAhead)
        XCTAssertEqual(plan.available, 3000)
        assertSameDay(plan.dayDate, today)

        // Another 5000 through income extends the FIXED date: Aug 14 → Aug 19.
        // Today's cushion stays 3000 — surplus never stretches the horizon.
        let extended = FoodMath.extendPlanEnd(current: planEnd, allocation: 5000, daily: daily, now: today)
        assertSameDay(extended, august(19))
        balance += 5000
        plan = FoodMath.plan(balance: balance, daily: daily, planEnd: extended, now: today)!
        XCTAssertEqual(plan.available, 3000)
        assertSameDay(plan.dayDate, today)
    }

    func testCarryOverToTomorrow() {
        // Underspending rolls into the next day: 1000 + 350 = 1350.
        let planEnd = FoodMath.extendPlanEnd(current: nil, allocation: 30000, daily: daily, now: august(9))
        let plan = FoodMath.plan(balance: 30000 - 650, daily: daily, planEnd: planEnd, now: august(10))!
        XCTAssertEqual(plan.available, 1350)
        assertSameDay(plan.dayDate, august(10))
    }

    func testIncomeAfterExpiredPlanAnchorsFresh() {
        let expired = august(1)
        let planEnd = FoodMath.extendPlanEnd(current: expired, allocation: 3000, daily: daily, now: august(10))
        assertSameDay(planEnd, august(12)) // 10th, 11th, 12th
    }

    func testAllocationSmallerThanDailyKeepsActivePlan() {
        let current = august(14)
        let planEnd = FoodMath.extendPlanEnd(current: current, allocation: 400, daily: daily, now: august(10))
        assertSameDay(planEnd, august(14))
    }
}
