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
        var days: [CategoryDetail.Load.ViewModel.DayCell] = []
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

                let weekdayFormatter = DateFormatter()
                weekdayFormatter.dateFormat = "EE"
                days = FoodMath.weekAhead(plan: plan, daily: response.dailyFoodAmount)
                    .enumerated().map { index, day in
                        .init(id: index,
                              weekday: weekdayFormatter.string(from: day.date).uppercased(),
                              amountText: MoneyFormat.amount(day.amount),
                              isMuted: day.isEaten,
                              isToday: day.isToday)
                    }
                if days.count < 2 { days = [] }
            }
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL yyyy"
        // Transactions arrive newest-first; group into month sections in order.
        var sections: [CategoryDetail.Load.ViewModel.MonthSection] = []
        var currentKey = ""
        var currentRows: [CategoryDetail.Load.ViewModel.Row] = []
        func flushSection() {
            guard !currentRows.isEmpty else { return }
            sections.append(.init(id: currentKey,
                                  title: currentKey.capitalized,
                                  rows: currentRows))
            currentRows = []
        }
        for transaction in response.transactions {
            let isOutflow = transaction.kind == .expense || transaction.kind == .transferOut
            let kindLabel: String
            switch transaction.kind {
            case .allocation: kindLabel = String(localized: "Income day")
            case .transferIn, .transferOut: kindLabel = String(localized: "Transfer")
            default: kindLabel = ""
            }
            let monthKey = monthFormatter.string(from: transaction.date)
            if monthKey != currentKey {
                flushSection()
                currentKey = monthKey
            }
            currentRows.append(CategoryDetail.Load.ViewModel.Row(
                id: transaction.id,
                dateText: Self.dateFormatter.string(from: transaction.date),
                note: transaction.note,
                amountText: (isOutflow ? "−" : "+")
                    + MoneyFormat.money(transaction.amount, symbol: symbol),
                isExpense: isOutflow,
                kindLabel: kindLabel,
                isEditable: transaction.kind == .expense || transaction.kind == .topUp
            ))
        }
        flushSection()

        var goalLine: String?
        if let goal = response.category.goalAmount, goal > 0 {
            let balance = max(0, response.balance)
            goalLine = "\(MoneyFormat.amount(balance)) / \(MoneyFormat.money(goal, symbol: symbol))"
            if let date = response.category.goalDate {
                goalLine! += String(localized: " · by \(FoodDay.dateText(date))")
            }
        }

        let viewModel = CategoryDetail.Load.ViewModel(
            title: response.category.name,
            balanceText: MoneyFormat.money(response.balance, symbol: symbol),
            isNegative: response.balance < 0,
            foodLine: foodLine,
            days: days,
            goalLine: goalLine,
            goalAmount: response.category.goalAmount,
            goalDate: response.category.goalDate,
            sections: sections
        )
        view?.displayDetail(viewModel: viewModel)
    }
}
