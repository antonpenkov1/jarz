import Foundation

@MainActor
protocol RecapPresentationLogic {
    func presentRecap(response: Recap.Load.Response)
}

@MainActor
final class RecapPresenter: RecapPresentationLogic {
    weak var view: RecapDisplayLogic?

    func presentRecap(response: Recap.Load.Response) {
        guard let start = response.periodStart else {
            view?.displayRecap(viewModel: .empty)
            return
        }
        let symbol = response.currencySymbol

        let totalSpent = response.jarStats.reduce(Decimal.zero) { $0 + $1.spent }

        let rows = response.jarStats.map { stat in
            Recap.Load.ViewModel.Row(
                id: stat.category.id,
                name: stat.category.name,
                amountsText: "\(MoneyFormat.amount(stat.spent)) / \(MoneyFormat.money(stat.allocated, symbol: symbol))",
                isOver: stat.spent > stat.allocated
            )
        }

        var foodLine: String?
        if response.hasFoodPlan && response.foodTotalDays > 0 {
            foodLine = String(localized: "\(response.foodOnPlanDays) of \(response.foodTotalDays) days within the food budget")
        }

        var topSpendingLine: String?
        if let top = response.jarStats.max(by: { $0.spent < $1.spent }), top.spent > 0 {
            topSpendingLine = String(localized: "Most spent: \(top.category.name) — \(MoneyFormat.money(top.spent, symbol: symbol))")
        }

        let maxSpent = response.pastPeriods.map(\.spent).max() ?? 0
        let pastRows = response.pastPeriods.enumerated().map { index, period in
            Recap.Load.ViewModel.PastRow(
                id: index,
                rangeText: "\(FoodDay.dateText(period.start)) – \(FoodDay.dateText(period.end))",
                amountsText: "\(MoneyFormat.amount(period.spent)) / \(MoneyFormat.money(period.allocated, symbol: symbol))",
                barValue: maxSpent > 0
                    ? (period.spent as NSDecimalNumber).doubleValue / (maxSpent as NSDecimalNumber).doubleValue
                    : 0
            )
        }

        view?.displayRecap(viewModel: .init(
            periodText: String(localized: "since \(FoodDay.dateText(start))"),
            totalSpentText: MoneyFormat.money(totalSpent, symbol: symbol),
            foodLine: foodLine,
            topSpendingLine: topSpendingLine,
            rows: rows,
            pastRows: pastRows,
            isEmpty: false
        ))
    }
}
