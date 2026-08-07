import Foundation

enum Reconciliation {
    enum Load {
        struct Request {}

        struct Response {
            let accounts: [ReconciliationAccount]
            let appTotal: Decimal
            let currencySymbol: String
            let revisions: [RevisionRecord]
            let categories: [BudgetCategory]
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
                let isNegative: Bool
                let plannedText: String
                let countedText: String
                let entries: [EntryRow]
            }
            struct JarOption: Identifiable {
                let id: UUID
                let name: String
            }
            let accounts: [AccountForm]
            let appTotal: Decimal
            let appTotalText: String
            let currencySymbol: String
            let revisions: [RevisionRow]
            let jars: [JarOption]

            static let empty = ViewModel(
                accounts: [], appTotal: 0, appTotalText: "", currencySymbol: "", revisions: [], jars: [])
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

    enum ZeroOut {
        struct Request {
            let categoryId: UUID
            /// Live difference from the form: counted − planned.
            let difference: Decimal
        }
    }
}
