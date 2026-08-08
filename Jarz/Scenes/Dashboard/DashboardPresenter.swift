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

            var days: [Dashboard.Load.ViewModel.FoodCard.DayCell] = []
            if !isNegative {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let weekdayFormatter = DateFormatter()
                weekdayFormatter.dateFormat = "EE"
                let aheadDays = calendar.dateComponents(
                    [.day], from: today, to: calendar.startOfDay(for: plan.dayDate)).day ?? 0
                for offset in 0..<7 {
                    guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                          date <= plan.planEnd else { break }
                    let amount: Decimal
                    if offset < aheadDays {
                        amount = 0
                    } else if offset == aheadDays {
                        amount = max(0, plan.available)
                    } else {
                        amount = daily
                    }
                    days.append(.init(
                        id: offset,
                        weekday: weekdayFormatter.string(from: date).uppercased(),
                        amountText: MoneyFormat.amount(amount),
                        isMuted: offset < aheadDays,
                        isToday: offset == 0
                    ))
                }
            }

            foodCard = Dashboard.Load.ViewModel.FoodCard(
                name: food.category.name,
                balanceText: MoneyFormat.money(food.balance, symbol: symbol),
                heroText: MoneyFormat.amount(isNegative ? food.balance : plan.available),
                heroCaption: isNegative
                    ? String(localized: "over budget")
                    : String(localized: "\(symbol) left for "),
                heroCaptionDay: isNegative ? "" : FoodDay.phrase(for: plan.dayDate),
                isDayAhead: !isNegative && plan.isAhead,
                daysText: isNegative
                    ? ""
                    : (plan.daysLeft > 0
                        ? String(localized: "+\(plan.daysLeft) days · until \(FoodDay.dateText(plan.planEnd))")
                        : String(localized: "last plan day · until \(FoodDay.dateText(plan.planEnd))")),
                isNegative: isNegative,
                dayProgress: progress,
                days: days
            )
        }

        let rows = response.others.map { entry -> Dashboard.Load.ViewModel.Row in
            var goalProgress: Double?
            var goalText: String?
            if let goal = entry.category.goalAmount, goal > 0 {
                let balance = max(0, entry.balance)
                goalProgress = min(1, (balance as NSDecimalNumber).doubleValue
                                   / (goal as NSDecimalNumber).doubleValue)
                var text = "\(MoneyFormat.amount(balance)) / \(MoneyFormat.money(goal, symbol: symbol))"
                if let date = entry.category.goalDate {
                    text += String(localized: " · by \(FoodDay.dateText(date))")
                    let remaining = goal - entry.balance
                    let months = max(1, (Calendar.current.dateComponents(
                        [.month], from: Date(), to: date).month ?? 0) + 1)
                    if remaining > 0 {
                        let perMonth = remaining / Decimal(months)
                        text += String(localized: " · \(MoneyFormat.amount(perMonth))/mo")
                    }
                }
                goalText = text
            }
            return Dashboard.Load.ViewModel.Row(
                id: entry.category.id,
                name: entry.category.name,
                balanceText: MoneyFormat.money(entry.balance, symbol: symbol),
                isNegative: entry.balance < 0,
                goalProgress: goalProgress,
                goalText: goalText
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
