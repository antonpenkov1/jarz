import Foundation

@MainActor
protocol ReconciliationBusinessLogic {
    func load(request: Reconciliation.Load.Request)
    func save(request: Reconciliation.Save.Request)
    func deleteRevision(request: Reconciliation.DeleteRevision.Request)
    func zeroOut(request: Reconciliation.ZeroOut.Request)
}

@MainActor
final class ReconciliationInteractor: ReconciliationBusinessLogic {
    private let presenter: ReconciliationPresentationLogic
    private let worker: StorageWorker

    init(presenter: ReconciliationPresentationLogic, worker: StorageWorker) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Reconciliation.Load.Request) {
        presenter.presentAccounts(response: .init(
            accounts: worker.accounts(),
            appTotal: worker.totalBalance(),
            currencySymbol: worker.settings().currencySymbol,
            revisions: worker.revisions(),
            categories: worker.sortedCategories()
        ))
    }

    /// Books the revision difference onto a jar so plan matches reality:
    /// missing money becomes an expense, surplus becomes a top-up.
    func zeroOut(request: Reconciliation.ZeroOut.Request) {
        guard request.difference != 0 else { return }
        worker.addTransaction(
            categoryId: request.categoryId,
            kind: request.difference < 0 ? .expense : .topUp,
            amount: abs(request.difference),
            note: String(localized: "Revision adjustment"),
            date: Date()
        )
        load(request: .init())
    }

    func save(request: Reconciliation.Save.Request) {
        let accounts = request.entries
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { entry in
                ReconciliationAccount(
                    id: entry.id,
                    name: entry.name,
                    amount: MoneyFormat.parse(entry.amountText) ?? 0
                )
            }
        worker.replaceAccounts(accounts)
        if !accounts.isEmpty {
            worker.addRevision(
                planned: worker.totalBalance(),
                counted: accounts.reduce(0) { $0 + $1.amount },
                entries: accounts.map { RevisionEntry(name: $0.name, amount: $0.amount) }
            )
        }
        load(request: .init())
    }

    func deleteRevision(request: Reconciliation.DeleteRevision.Request) {
        worker.deleteRevision(id: request.id)
        load(request: .init())
    }
}
