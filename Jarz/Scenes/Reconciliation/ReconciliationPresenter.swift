import Foundation

protocol ReconciliationPresentationLogic {
    func presentAccounts(response: Reconciliation.Load.Response)
}

final class ReconciliationPresenter: ReconciliationPresentationLogic {
    weak var view: ReconciliationDisplayLogic?

    func presentAccounts(response: Reconciliation.Load.Response) {
        let accounts = response.accounts.map {
            Reconciliation.Load.ViewModel.AccountForm(
                id: $0.id,
                name: $0.name,
                amountText: $0.amount == 0 ? "" : MoneyFormat.amount($0.amount).replacingOccurrences(of: " ", with: "")
            )
        }
        view?.displayAccounts(viewModel: .init(
            accounts: accounts,
            appTotal: response.appTotal,
            appTotalText: MoneyFormat.money(response.appTotal, symbol: response.currencySymbol),
            currencySymbol: response.currencySymbol
        ))
    }
}
