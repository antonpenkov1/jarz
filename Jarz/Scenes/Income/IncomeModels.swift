import Foundation

enum Income {
    enum Prepare {
        struct Request {}

        struct Response {
            struct Prefill {
                let category: BudgetCategory
                let amount: Decimal
                let autoHint: String?
            }
            let prefills: [Prefill]
            let currencySymbol: String
        }

        struct ViewModel {
            struct Row: Identifiable {
                let id: UUID
                let name: String
                let prefillText: String
                let autoHint: String?
            }
            let rows: [Row]
            let currencySymbol: String

            static let empty = ViewModel(rows: [], currencySymbol: "")
        }
    }

    enum Save {
        struct Request {
            /// Category id → user-entered amount text.
            let amounts: [UUID: String]
        }

        struct Response {
            let allocatedTotal: Decimal
            let currencySymbol: String
        }

        struct ViewModel {
            let message: String
        }
    }
}
