import Foundation

enum CategoryDetail {
    enum Load {
        struct Request {}

        struct Response {
            let category: BudgetCategory
            let balance: Decimal
            let isFoodCategory: Bool
            let dailyFoodAmount: Decimal
            let foodPlanEnd: Date?
            let transactions: [MoneyTransaction]
            let currencySymbol: String
        }

        struct ViewModel {
            struct Row: Identifiable {
                let id: UUID
                let dateText: String
                let note: String
                let amountText: String
                let isExpense: Bool
                let kindLabel: String
                let isEditable: Bool
            }
            struct DayCell: Identifiable {
                let id: Int
                let weekday: String
                let amountText: String
                let isMuted: Bool
                let isToday: Bool
            }
            let title: String
            let balanceText: String
            let isNegative: Bool
            let foodLine: String?
            /// The next week of the food plan; empty for non-food jars.
            let days: [DayCell]
            let goalLine: String?
            let goalAmount: Decimal?
            let goalDate: Date?
            let rows: [Row]

            static let empty = ViewModel(
                title: "", balanceText: "", isNegative: false, foodLine: nil, days: [],
                goalLine: nil, goalAmount: nil, goalDate: nil, rows: []
            )
        }
    }

    enum SaveTransaction {
        struct Request {
            /// nil when adding a new transaction.
            let transactionId: UUID?
            let isExpense: Bool
            let amountText: String
            let note: String
        }
    }

    enum DeleteTransaction {
        struct Request {
            let transactionId: UUID
        }
    }

    enum SetGoal {
        struct Request {
            /// nil clears the goal.
            let amount: Decimal?
            let date: Date?
        }
    }

    enum Transfer {
        struct Request {
            let toId: UUID
            let amount: Decimal
        }
    }
}
