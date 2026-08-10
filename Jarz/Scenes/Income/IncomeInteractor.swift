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
        let settings = worker.settings()
        let symbol = settings.currencySymbol

        let prefills = worker.sortedCategories().map { category -> Income.Prepare.Response.Prefill in
            if category.id == settings.foodCategoryId && settings.dailyFoodAmount > 0 {
                let amount = settings.dailyFoodAmount * Decimal(AppSettings.foodHorizonDays)
                let daily = MoneyFormat.money(settings.dailyFoodAmount, symbol: symbol)
                return .init(
                    category: category,
                    amount: amount,
                    autoHint: String(localized: "auto: \(daily) × \(AppSettings.foodHorizonDays) days")
                )
            }
            if category.id == settings.apartmentCategoryId && settings.apartmentAmount > 0 {
                return .init(category: category, amount: settings.apartmentAmount,
                             autoHint: String(localized: "auto: monthly fixed"))
            }
            if category.id == settings.billsCategoryId && settings.billsAmount > 0 {
                return .init(category: category, amount: settings.billsAmount,
                             autoHint: String(localized: "auto: monthly fixed"))
            }
            return .init(category: category, amount: 0, autoHint: nil)
        }

        presenter.presentPrepared(response: .init(prefills: prefills, currencySymbol: symbol))
    }

    func save(request: Income.Save.Request) {
        var allocated = Decimal.zero
        let date = Date()
        var foodAllocation = Decimal.zero
        var settings = worker.settings()
        for category in worker.sortedCategories() {
            guard let text = request.amounts[category.id],
                  let amount = MoneyFormat.parse(text), amount > 0 else { continue }
            allocated += amount
            if category.id == settings.foodCategoryId { foodAllocation = amount }
            worker.addTransaction(
                categoryId: category.id,
                kind: .allocation,
                amount: amount,
                note: String(localized: "Income"),
                date: date
            )
        }
        // Income extends the fixed food horizon by exactly allocation/daily
        // days; nothing else ever moves that date. Surplus stays with today.
        if foodAllocation > 0, settings.foodCategoryId != nil, settings.dailyFoodAmount > 0 {
            settings.foodPlanEnd = FoodMath.extendPlanEnd(
                current: settings.foodPlanEnd,
                allocation: foodAllocation,
                daily: settings.dailyFoodAmount,
                now: date
            )
            worker.saveSettings(settings)
        }
        presenter.presentSaved(response: .init(
            allocatedTotal: allocated,
            currencySymbol: worker.settings().currencySymbol
        ))
        prepare(request: .init())
    }
}
