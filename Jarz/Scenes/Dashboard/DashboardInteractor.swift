import Foundation

protocol DashboardBusinessLogic {
    func load(request: Dashboard.Load.Request)
}

final class DashboardInteractor: DashboardBusinessLogic {
    private let presenter: DashboardPresentationLogic
    private let worker: StorageWorker

    init(presenter: DashboardPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Dashboard.Load.Request) {
        let settings = worker.state.settings
        let categories = worker.sortedCategories()

        var food: Dashboard.Load.Response.CategoryBalance?
        var others: [Dashboard.Load.Response.CategoryBalance] = []

        for category in categories {
            let entry = Dashboard.Load.Response.CategoryBalance(
                category: category,
                balance: worker.balance(of: category.id)
            )
            if category.id == settings.foodCategoryId && settings.dailyFoodAmount > 0 {
                food = entry
            } else {
                others.append(entry)
            }
        }

        let response = Dashboard.Load.Response(
            food: food,
            others: others,
            dailyFoodAmount: settings.dailyFoodAmount,
            total: worker.totalBalance(),
            currencySymbol: settings.currencySymbol
        )
        presenter.presentDashboard(response: response)
    }
}
