import Foundation

protocol CategoryDetailPresentationLogic {
    func presentDetail(response: CategoryDetail.Load.Response)
}

final class CategoryDetailPresenter: CategoryDetailPresentationLogic {
    weak var view: CategoryDetailDisplayLogic?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    func presentDetail(response: CategoryDetail.Load.Response) {
        let symbol = response.currencySymbol

        var foodLine: String?
        if response.isFoodCategory,
           let plan = FoodMath.plan(balance: response.balance, daily: response.dailyFoodAmount,
                                    planEnd: response.foodPlanEnd) {
            if response.balance < 0 {
                foodLine = String(localized: "Over budget")
            } else {
                let money = MoneyFormat.money(plan.available, symbol: symbol)
                foodLine = String(localized: "\(money) for \(FoodDay.phrase(for: plan.dayDate))")
                    + (plan.daysLeft > 0
                        ? String(localized: " · +\(plan.daysLeft) days until \(FoodDay.dateText(plan.planEnd))")
                        : String(localized: " · until \(FoodDay.dateText(plan.planEnd))"))
            }
        }

        let rows = response.transactions.map { transaction in
            CategoryDetail.Load.ViewModel.Row(
                id: transaction.id,
                dateText: Self.dateFormatter.string(from: transaction.date),
                note: transaction.note,
                amountText: (transaction.kind == .expense ? "−" : "+")
                    + MoneyFormat.money(transaction.amount, symbol: symbol),
                isExpense: transaction.kind == .expense,
                kindLabel: transaction.kind == .allocation ? String(localized: "Income day") : ""
            )
        }

        let viewModel = CategoryDetail.Load.ViewModel(
            title: response.category.name,
            balanceText: MoneyFormat.money(response.balance, symbol: symbol),
            isNegative: response.balance < 0,
            foodLine: foodLine,
            rows: rows
        )
        view?.displayDetail(viewModel: viewModel)
    }
}
