import Foundation

protocol ReconciliationPresentationLogic {
    func presentAccounts(response: Reconciliation.Load.Response)
}

final class ReconciliationPresenter: ReconciliationPresentationLogic {
    weak var view: ReconciliationDisplayLogic?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy · HH:mm"
        return f
    }()

    func presentAccounts(response: Reconciliation.Load.Response) {
        let symbol = response.currencySymbol
        let accounts = response.accounts.map {
            Reconciliation.Load.ViewModel.AccountForm(
                id: $0.id,
                name: $0.name,
                amountText: $0.amount == 0 ? "" : MoneyFormat.amount($0.amount).replacingOccurrences(of: " ", with: "")
            )
        }
        let revisions = response.revisions.map { record in
            Reconciliation.Load.ViewModel.RevisionRow(
                id: record.id,
                dateText: Self.dateFormatter.string(from: record.date),
                differenceText: (record.difference > 0 ? "+" : "")
                    + MoneyFormat.money(record.difference, symbol: symbol),
                isBalanced: record.difference == 0,
                plannedText: MoneyFormat.money(record.planned, symbol: symbol),
                countedText: MoneyFormat.money(record.counted, symbol: symbol),
                entries: record.entries.enumerated().map { index, entry in
                    .init(id: index, name: entry.name,
                          amountText: MoneyFormat.money(entry.amount, symbol: symbol))
                }
            )
        }
        view?.displayAccounts(viewModel: .init(
            accounts: accounts,
            appTotal: response.appTotal,
            appTotalText: MoneyFormat.money(response.appTotal, symbol: symbol),
            currencySymbol: symbol,
            revisions: revisions
        ))
    }
}
