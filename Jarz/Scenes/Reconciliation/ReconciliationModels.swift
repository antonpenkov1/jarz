import Foundation

enum Reconciliation {
    enum Load {
        struct Request {}

        struct Response {
            let accounts: [ReconciliationAccount]
            let appTotal: Decimal
            let currencySymbol: String
            let revisions: [RevisionRecord]
        }

        struct ViewModel {
            struct AccountForm: Identifiable {
                let id: UUID
                var name: String
                var amountText: String
            }
            struct RevisionRow: Identifiable {
                struct EntryRow: Identifiable {
                    let id: Int
                    let name: String
                    let amountText: String
                }
                let id: UUID
                let dateText: String
                let differenceText: String
                let isBalanced: Bool
                let plannedText: String
                let countedText: String
                let entries: [EntryRow]
            }
            let accounts: [AccountForm]
            let appTotal: Decimal
            let appTotalText: String
            let currencySymbol: String
            let revisions: [RevisionRow]

            static let empty = ViewModel(
                accounts: [], appTotal: 0, appTotalText: "", currencySymbol: "", revisions: [])
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

    enum DeleteRevision {
        struct Request {
            let id: UUID
        }
    }
}
