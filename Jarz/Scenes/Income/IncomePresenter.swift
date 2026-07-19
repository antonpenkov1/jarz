import Foundation

protocol IncomePresentationLogic {
    func presentPrepared(response: Income.Prepare.Response)
    func presentSaved(response: Income.Save.Response)
}

final class IncomePresenter: IncomePresentationLogic {
    weak var view: IncomeDisplayLogic?

    func presentPrepared(response: Income.Prepare.Response) {
        let rows = response.prefills.map { prefill in
            Income.Prepare.ViewModel.Row(
                id: prefill.category.id,
                name: prefill.category.name,
                prefillText: prefill.amount > 0 ? MoneyFormat.amount(prefill.amount).replacingOccurrences(of: " ", with: "") : "",
                autoHint: prefill.autoHint
            )
        }
        view?.displayPrepared(viewModel: .init(rows: rows, currencySymbol: response.currencySymbol))
    }

    func presentSaved(response: Income.Save.Response) {
        let total = MoneyFormat.money(response.allocatedTotal, symbol: response.currencySymbol)
        view?.displaySaved(viewModel: .init(message: "Added \(total) to your categories."))
    }
}
