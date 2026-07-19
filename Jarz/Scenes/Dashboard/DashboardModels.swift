import Foundation

enum Dashboard {
    enum Load {
        struct Request {}

        struct Response {
            struct CategoryBalance {
                let category: BudgetCategory
                let balance: Decimal
            }
            let food: CategoryBalance?
            let others: [CategoryBalance]
            let dailyFoodAmount: Decimal
            let foodSpentToday: Decimal
            let total: Decimal
            let currencySymbol: String
        }

        struct ViewModel {
            struct FoodCard {
                let name: String
                let balanceText: String
                /// Big serif numeral: what's left for the current day.
                let heroText: String
                let heroCaption: String
                let daysText: String
                let isNegative: Bool
                let dayProgress: Double
            }
            struct Row: Identifiable {
                let id: UUID
                let name: String
                let balanceText: String
                let isNegative: Bool
            }
            let foodCard: FoodCard?
            let rows: [Row]
            let totalText: String

            static let empty = ViewModel(foodCard: nil, rows: [], totalText: "")
        }
    }
}
