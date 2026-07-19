import Foundation

enum CategoryDetail {
    enum Load {
        struct Request {}

        struct Response {
            let category: BudgetCategory
            let balance: Decimal
            let isFoodCategory: Bool
            let dailyFoodAmount: Decimal
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
            }
            let title: String
            let balanceText: String
            let isNegative: Bool
            let foodLine: String?
            let rows: [Row]

            static let empty = ViewModel(
                title: "", balanceText: "", isNegative: false, foodLine: nil, rows: []
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
}
