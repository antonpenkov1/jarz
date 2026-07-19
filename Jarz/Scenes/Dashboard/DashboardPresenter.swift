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
           let split = FoodMath.breakdown(balance: food.balance, daily: response.dailyFoodAmount) {
            let isNegative = food.balance < 0
            let daily = response.dailyFoodAmount
            let progress = daily > 0 && split.remainder > 0
                ? min(1, (split.remainder as NSDecimalNumber).doubleValue / (daily as NSDecimalNumber).doubleValue)
                : 0
            let day = FoodDay.currentDayPhrase(spentToday: response.foodSpentToday, daily: daily)
            let coveredUntil = Calendar.current.date(byAdding: .day, value: split.fullDays, to: day.dayDate) ?? day.dayDate
            foodCard = Dashboard.Load.ViewModel.FoodCard(
                name: food.category.name,
                balanceText: MoneyFormat.money(food.balance, symbol: symbol),
                heroText: MoneyFormat.amount(isNegative ? food.balance : split.remainder),
                heroCaption: isNegative ? "over budget" : "\(symbol) left for \(day.phrase)",
                daysText: isNegative
                    ? ""
                    : "+\(split.fullDays) full day\(split.fullDays == 1 ? "" : "s") · until \(FoodDay.dateText(coveredUntil))",
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
