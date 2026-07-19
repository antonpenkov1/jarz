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
            accounts: worker.state.accounts,
            appTotal: worker.totalBalance(),
            currencySymbol: worker.state.settings.currencySymbol
        ))
    }

    func save(request: Reconciliation.Save.Request) {
        worker.update { state in
            state.accounts = request.entries
                .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { entry in
                    ReconciliationAccount(
                        id: entry.id,
                        name: entry.name,
                        amount: MoneyFormat.parse(entry.amountText) ?? 0
                    )
                }
        }
        load(request: .init())
    }
}
