import Foundation

protocol ReconciliationBusinessLogic {
    func load(request: Reconciliation.Load.Request)
    func save(request: Reconciliation.Save.Request)
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
            currencySymbol: worker.settings().currencySymbol
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
        load(request: .init())
    }
}
