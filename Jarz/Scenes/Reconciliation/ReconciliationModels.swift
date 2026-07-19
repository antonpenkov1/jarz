import Foundation

enum Reconciliation {
    enum Load {
        struct Request {}

        struct Response {
            let accounts: [ReconciliationAccount]
            let appTotal: Decimal
            let currencySymbol: String
        }

        struct ViewModel {
            struct AccountForm: Identifiable {
                let id: UUID
                var name: String
                var amountText: String
            }
            let accounts: [AccountForm]
            let appTotal: Decimal
            let appTotalText: String
            let currencySymbol: String

            static let empty = ViewModel(accounts: [], appTotal: 0, appTotalText: "", currencySymbol: "")
        }
    }

    enum Save {
        struct Request {
            struct Entry {
                let id: UUID
                let name: String
                let amountText: String
            }
            let entries: [Entry]
        }
    }
}
