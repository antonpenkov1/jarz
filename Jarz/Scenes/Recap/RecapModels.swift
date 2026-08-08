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
            struct PastPeriod {
                let start: Date
                let end: Date
                let spent: Decimal
                let allocated: Decimal
            }
            /// Start of the current period — the latest income day. nil = no income yet.
            let periodStart: Date?
            let jarStats: [JarStat]
            let foodOnPlanDays: Int
            let foodTotalDays: Int
            let hasFoodPlan: Bool
            /// Closed periods, most recent first.
            let pastPeriods: [PastPeriod]
            let currencySymbol: String
        }

        struct ViewModel {
            struct Row: Identifiable {
                let id: UUID
                let name: String
                let amountsText: String
                let isOver: Bool
            }
            struct PastRow: Identifiable {
                let id: Int
                let rangeText: String
                let amountsText: String
                /// 0…1 relative to the biggest period, drives the bar chart.
                let barValue: Double
            }
            let periodText: String
            let totalSpentText: String
            let foodLine: String?
            let topSpendingLine: String?
            let rows: [Row]
            let pastRows: [PastRow]
            let isEmpty: Bool

            static let empty = ViewModel(
                periodText: "", totalSpentText: "", foodLine: nil,
                topSpendingLine: nil, rows: [], pastRows: [], isEmpty: true)
        }
    }
}
