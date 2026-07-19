import Foundation

protocol ReconciliationBusinessLogic {
    func load(request: Reconciliation.Load.Request)
    func save(request: Reconciliation.Save.Request)
    func deleteRevision(request: Reconciliation.DeleteRevision.Request)
}

final class ReconciliationInteractor: ReconciliationBusinessLogic {
    private let presenter: ReconciliationPresentationLogic
    private let worker: StorageWorker

    init(presenter: ReconciliationPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Reconciliation.Load.Request) {
        presenter.presentAccounts(response: .init(
            accounts: worker.accounts(),
            appTotal: worker.totalBalance(),
            currencySymbol: worker.settings().currencySymbol,
            revisions: worker.revisions()
        ))
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
