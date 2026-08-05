import Foundation

protocol DashboardPresentationLogic {
    func presentDashboard(response: Dashboard.Load.Response)
}

final class DashboardPresenter: DashboardPresentationLogic {
    weak var view: DashboardDisplayLogic?

    func presentDashboard(response: Dashboard.Load.Response) {
        let symbol = response.currencySymbol

        var foodCard: Dashboard.Load.ViewModel.FoodCard?
        if let food = response.food,
           let plan = FoodMath.plan(balance: food.balance, daily: response.dailyFoodAmount,
                                    planEnd: response.foodPlanEnd) {
            let isNegative = food.balance < 0
            let daily = response.dailyFoodAmount
            let progress = plan.available > 0
                ? min(1, (plan.available as NSDecimalNumber).doubleValue / (daily as NSDecimalNumber).doubleValue)
                : 0
            foodCard = Dashboard.Load.ViewModel.FoodCard(
                name: food.category.name,
                balanceText: MoneyFormat.money(food.balance, symbol: symbol),
                heroText: MoneyFormat.amount(isNegative ? food.balance : plan.available),
                heroCaption: isNegative ? "over budget" : "\(symbol) left for ",
                heroCaptionDay: isNegative ? "" : FoodDay.phrase(for: plan.dayDate),
                isDayAhead: !isNegative && plan.isAhead,
                daysText: isNegative
                    ? ""
                    : (plan.daysLeft > 0
                        ? "+\(plan.daysLeft) day\(plan.daysLeft == 1 ? "" : "s") · until \(FoodDay.dateText(plan.planEnd))"
                        : "last plan day · until \(FoodDay.dateText(plan.planEnd))"),
                isNegative: isNegative,
                dayProgress: progress
            )
        }

        let rows = response.others.map {
            Dashboard.Load.ViewModel.Row(
                id: $0.category.id,
                name: $0.category.name,
                balanceText: MoneyFormat.money($0.balance, symbol: symbol),
                isNegative: $0.balance < 0
            )
        }

        let viewModel = Dashboard.Load.ViewModel(
            foodCard: foodCard,
            rows: rows,
            totalText: MoneyFormat.money(response.total, symbol: symbol)
        )
        view?.displayDashboard(viewModel: viewModel)
    }
}
