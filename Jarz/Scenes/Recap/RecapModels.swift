import Foundation

enum Recap {
    enum Load {
        struct Request {}

        struct Response {
            struct JarStat {
                let category: BudgetCategory
                let allocated: Decimal
                let spent: Decimal
            }
            /// Start of the current period — the latest income day. nil = no income yet.
            let periodStart: Date?
            let jarStats: [JarStat]
            let foodOnPlanDays: Int
            let foodTotalDays: Int
            let hasFoodPlan: Bool
            let currencySymbol: String
        }

        struct ViewModel {
            struct Row: Identifiable {
                let id: UUID
                let name: String
                let amountsText: String
                let isOver: Bool
            }
            let periodText: String
            let totalSpentText: String
            let foodLine: String?
            let topSpendingLine: String?
            let rows: [Row]
            let isEmpty: Bool

            static let empty = ViewModel(
                periodText: "", totalSpentText: "", foodLine: nil,
                topSpendingLine: nil, rows: [], isEmpty: true)
        }
    }
}
