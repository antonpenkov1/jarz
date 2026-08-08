import Foundation

struct BudgetCategory: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var order: Int
    var goalAmount: Decimal?
    var goalDate: Date?
}

enum TransactionKind: String, Codable, CaseIterable {
    case allocation
    case expense
    case topUp
    case transferIn
    case transferOut
}

struct MoneyTransaction: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var categoryId: UUID
    var kind: TransactionKind
    /// Always stored positive; sign is derived from `kind`.
    var amount: Decimal
    var note: String = ""
    var date: Date

    var signedAmount: Decimal {
        kind == .expense || kind == .transferOut ? -amount : amount
    }
}

struct AppSettings: Codable {
    var currencySymbol: String = "RSD"
    var foodCategoryId: UUID?
    var dailyFoodAmount: Decimal = 0
    var apartmentCategoryId: UUID?
    var apartmentAmount: Decimal = 0
    var billsCategoryId: UUID?
    var billsAmount: Decimal = 0
    /// Last day of the current food plan. Fixed when income is allocated to
    /// the food jar; day-to-day spending never moves it.
    var foodPlanEnd: Date?

    static let foodHorizonDays = 31
}

struct ReconciliationAccount: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: Decimal = 0
}

/// One card/cash line inside a saved revision snapshot.
struct RevisionEntry: Codable, Hashable {
    var name: String
    var amount: Decimal
}

/// A saved revision: plan vs reality at a moment in time.
struct RevisionRecord: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var planned: Decimal
    var counted: Decimal
    var entries: [RevisionEntry]
    var difference: Decimal { counted - planned }
}

struct AppState: Codable {
    var categories: [BudgetCategory] = []
    var transactions: [MoneyTransaction] = []
    var settings: AppSettings = AppSettings()
    var accounts: [ReconciliationAccount] = []
}

enum FoodDay {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    static func dateText(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// "today, 5 Aug" / "tomorrow, 6 Aug" / "8 Aug" for an absolute day.
    static func phrase(for dayDate: Date, relativeTo now: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dayDate)
        ).day ?? 0
        let dateText = formatter.string(from: dayDate)
        switch days {
        case 0: return String(localized: "today, \(dateText)")
        case 1: return String(localized: "tomorrow, \(dateText)")
        default: return dateText
        }
    }
}

enum FoodMath {
    /// The food plan is anchored to the calendar: income fixes `planEnd`, and
    /// every day up to it owns one daily budget. Whatever a day doesn't spend
    /// carries forward; overspending eats concrete future days.
    struct FoodPlan {
        /// Money belonging to `dayDate` (today, or the first future day that
        /// still has money after an overspend).
        let available: Decimal
        let dayDate: Date
        /// True when today's budget is fully eaten and `dayDate` is in the future.
        let isAhead: Bool
        /// Plan days remaining after `dayDate`.
        let daysLeft: Int
        let planEnd: Date
    }

    /// available(today) = balance − daily × (plan days after today).
    /// This single identity yields all the desired behavior: leftovers roll
    /// into the next day, top-ups land on today, and `planEnd` never moves.
    static func plan(balance: Decimal, daily: Decimal, planEnd: Date?, now: Date = Date()) -> FoodPlan? {
        guard daily > 0 else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var end: Date
        if let planEnd {
            end = calendar.startOfDay(for: planEnd)
        } else {
            // No plan anchored yet (before the first income): derive one so the
            // card still makes sense; it becomes fixed on the next income.
            end = calendar.date(byAdding: .day, value: max(0, Self.wholeDays(balance / daily) - 1), to: today) ?? today
        }
        if end < today { end = today } // plan ran out — everything left is today's

        let remainingAfterToday = calendar.dateComponents([.day], from: today, to: end).day ?? 0
        let availableToday = balance - daily * Decimal(remainingAfterToday)

        if availableToday > 0 || remainingAfterToday == 0 {
            return FoodPlan(available: availableToday, dayDate: today,
                            isAhead: false, daysLeft: remainingAfterToday, planEnd: end)
        }
        // Today is spent through — find the first future day that has money.
        let deficit = -availableToday
        let ahead = min(Self.wholeDays(deficit / daily) + 1, remainingAfterToday)
        let dayDate = calendar.date(byAdding: .day, value: ahead, to: today) ?? today
        return FoodPlan(available: availableToday + daily * Decimal(ahead), dayDate: dayDate,
                        isAhead: true, daysLeft: remainingAfterToday - ahead, planEnd: end)
    }

    /// Fixes the plan horizon from the balance at income time:
    /// today plus one day per full daily budget in the balance.
    static func planEnd(balance: Decimal, daily: Decimal, now: Date = Date()) -> Date? {
        guard daily > 0, balance > 0 else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: max(0, Self.wholeDays(balance / daily) - 1), to: today)
    }

    private static func wholeDays(_ value: Decimal) -> Int {
        let handler = NSDecimalNumberHandler(
            roundingMode: .down, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        return (value as NSDecimalNumber).rounding(accordingToBehavior: handler).intValue
    }
}
