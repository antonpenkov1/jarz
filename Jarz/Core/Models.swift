import Foundation

struct BudgetCategory: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var order: Int
}

enum TransactionKind: String, Codable, CaseIterable {
    case allocation
    case expense
    case topUp
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
        kind == .expense ? -amount : amount
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

    static let foodHorizonDays = 31
}

struct ReconciliationAccount: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: Decimal = 0
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

    /// "today, 19 Jul" / "tomorrow, 20 Jul" / "22 Jul" — which day the
    /// remainder belongs to, judged by how much was already spent today.
    static func currentDayPhrase(spentToday: Decimal, daily: Decimal, now: Date = Date()) -> (phrase: String, dayDate: Date) {
        let offset = FoodMath.daysEatenAhead(spentToday: spentToday, daily: daily)
        let dayDate = Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
        let dateText = formatter.string(from: dayDate)
        switch offset {
        case 0: return ("today, \(dateText)", dayDate)
        case 1: return ("tomorrow, \(dateText)", dayDate)
        default: return (dateText, dayDate)
        }
    }
}

enum FoodMath {
    /// How many whole daily budgets today's spending has consumed.
    /// 0 — the remainder still belongs to today; 1 — today's budget is fully
    /// eaten and the remainder belongs to tomorrow; 2 — the day after, etc.
    static func daysEatenAhead(spentToday: Decimal, daily: Decimal) -> Int {
        guard daily > 0, spentToday >= daily else { return 0 }
        let handler = NSDecimalNumberHandler(
            roundingMode: .down, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        return (spentToday as NSDecimalNumber)
            .dividing(by: daily as NSDecimalNumber)
            .rounding(accordingToBehavior: handler)
            .intValue
    }

    /// Splits a balance into full days at the daily rate plus the remainder
    /// available on the current (partially spent) day. Calendar-independent:
    /// the remainder always belongs to the earliest unfinished day.
    static func breakdown(balance: Decimal, daily: Decimal) -> (fullDays: Int, remainder: Decimal)? {
        guard daily > 0 else { return nil }
        guard balance > 0 else { return (0, balance) }
        let handler = NSDecimalNumberHandler(
            roundingMode: .down, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        let quotient = (balance as NSDecimalNumber)
            .dividing(by: daily as NSDecimalNumber)
            .rounding(accordingToBehavior: handler)
        let fullDays = quotient.intValue
        let remainder = balance - quotient.decimalValue * daily
        // A perfectly even balance means the "current" day still has its full amount.
        if remainder == 0 && fullDays > 0 {
            return (fullDays - 1, daily)
        }
        return (fullDays, remainder)
    }
}
