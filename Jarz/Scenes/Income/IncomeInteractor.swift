import Foundation

protocol IncomeBusinessLogic {
    func prepare(request: Income.Prepare.Request)
    func save(request: Income.Save.Request)
}

final class IncomeInteractor: IncomeBusinessLogic {
    private let presenter: IncomePresentationLogic
    private let worker: StorageWorker

    init(presenter: IncomePresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func prepare(request: Income.Prepare.Request) {
        let settings = worker.state.settings
        let symbol = settings.currencySymbol

        let prefills = worker.sortedCategories().map { category -> Income.Prepare.Response.Prefill in
            if category.id == settings.foodCategoryId && settings.dailyFoodAmount > 0 {
                let amount = settings.dailyFoodAmount * Decimal(AppSettings.foodHorizonDays)
                return .init(
                    category: category,
                    amount: amount,
                    autoHint: "auto: \(MoneyFormat.money(settings.dailyFoodAmount, symbol: symbol)) × \(AppSettings.foodHorizonDays) days"
                )
            }
            if category.id == settings.apartmentCategoryId && settings.apartmentAmount > 0 {
                return .init(category: category, amount: settings.apartmentAmount, autoHint: "auto: monthly fixed")
            }
            if category.id == settings.billsCategoryId && settings.billsAmount > 0 {
                return .init(category: category, amount: settings.billsAmount, autoHint: "auto: monthly fixed")
            }
            return .init(category: category, amount: 0, autoHint: nil)
        }

        presenter.presentPrepared(response: .init(prefills: prefills, currencySymbol: symbol))
    }

    func save(request: Income.Save.Request) {
        var allocated = Decimal.zero
        let date = Date()
        worker.update { state in
            for category in state.categories {
                guard let text = request.amounts[category.id],
                      let amount = MoneyFormat.parse(text), amount > 0 else { continue }
                allocated += amount
                state.transactions.append(MoneyTransaction(
                    categoryId: category.id,
                    kind: .allocation,
                    amount: amount,
                    note: "Income",
                    date: date
                ))
            }
        }
        presenter.presentSaved(response: .init(
            allocatedTotal: allocated,
            currencySymbol: worker.state.settings.currencySymbol
        ))
        prepare(request: .init())
    }
}
