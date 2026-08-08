import Foundation

protocol RecapBusinessLogic {
    func load(request: Recap.Load.Request)
}

final class RecapInteractor: RecapBusinessLogic {
    private let presenter: RecapPresentationLogic
    private let worker: StorageWorker

    init(presenter: RecapPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Recap.Load.Request) {
        let settings = worker.settings()
        let categories = worker.sortedCategories()
        let byCategory = categories.map { ($0, worker.transactions(categoryId: $0.id)) }

        // The latest income day opens the current period.
        let periodStart = byCategory
            .flatMap { $0.1 }
            .filter { $0.kind == .allocation }
            .map(\.date)
            .max()
            .map { Calendar.current.startOfDay(for: $0) }

        var jarStats: [Recap.Load.Response.JarStat] = []
        var foodOnPlanDays = 0
        var foodTotalDays = 0

        if let start = periodStart {
            for (category, transactions) in byCategory {
                let inPeriod = transactions.filter { $0.date >= start }
                let allocated = inPeriod
                    .filter { $0.kind == .allocation || $0.kind == .topUp || $0.kind == .transferIn }
                    .reduce(Decimal.zero) { $0 + $1.amount }
                let spent = inPeriod
                    .filter { $0.kind == .expense || $0.kind == .transferOut }
                    .reduce(Decimal.zero) { $0 + $1.amount }
                jarStats.append(.init(category: category, allocated: allocated, spent: spent))
            }

            // Food discipline: how many days stayed within the daily budget.
            if let foodId = settings.foodCategoryId, settings.dailyFoodAmount > 0,
               let foodTransactions = byCategory.first(where: { $0.0.id == foodId })?.1 {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                var day = start
                while day <= today {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? today
                    let spentThatDay = foodTransactions
                        .filter { $0.kind == .expense && $0.date >= day && $0.date < nextDay }
                        .reduce(Decimal.zero) { $0 + $1.amount }
                    foodTotalDays += 1
                    if spentThatDay <= settings.dailyFoodAmount { foodOnPlanDays += 1 }
                    day = nextDay
                }
            }
        }

        // Closed periods: consecutive pairs of distinct income days (newest first).
        var pastPeriods: [Recap.Load.Response.PastPeriod] = []
        let calendar = Calendar.current
        let allTransactions = byCategory.flatMap { $0.1 }
        let incomeDays = Set(allTransactions
            .filter { $0.kind == .allocation }
            .map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)
        for (index, start) in incomeDays.enumerated() where index > 0 {
            let end = incomeDays[index - 1]
            let inPeriod = allTransactions.filter { $0.date >= start && $0.date < end }
            let spent = inPeriod
                .filter { $0.kind == .expense || $0.kind == .transferOut }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let allocated = inPeriod
                .filter { $0.kind == .allocation || $0.kind == .topUp || $0.kind == .transferIn }
                .reduce(Decimal.zero) { $0 + $1.amount }
            pastPeriods.append(.init(start: start, end: end, spent: spent, allocated: allocated))
            if pastPeriods.count == 6 { break }
        }

        presenter.presentRecap(response: .init(
            periodStart: periodStart,
            jarStats: jarStats,
            foodOnPlanDays: foodOnPlanDays,
            foodTotalDays: foodTotalDays,
            hasFoodPlan: settings.foodCategoryId != nil && settings.dailyFoodAmount > 0,
            pastPeriods: pastPeriods,
            currencySymbol: settings.currencySymbol
        ))
    }
}
