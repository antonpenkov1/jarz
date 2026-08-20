import Foundation

@MainActor
protocol SettingsBusinessLogic {
    func load(request: Settings.Load.Request)
    func saveSettings(request: Settings.SaveSettings.Request)
    func addCategory(request: Settings.AddCategory.Request)
    func renameCategory(request: Settings.RenameCategory.Request)
    func deleteCategory(request: Settings.DeleteCategory.Request)
    func undoDeleteCategory()
    func moveCategory(request: Settings.MoveCategory.Request)
}

@MainActor
final class SettingsInteractor: SettingsBusinessLogic {
    private let presenter: SettingsPresentationLogic
    private let worker: StorageWorker

    init(presenter: SettingsPresentationLogic, worker: StorageWorker) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Settings.Load.Request) {
        presenter.presentSettings(response: .init(
            settings: worker.settings(),
            categories: worker.sortedCategories()
        ))
    }

    func saveSettings(request: Settings.SaveSettings.Request) {
        var settings = worker.settings()
        settings.currencySymbol = request.currencySymbol
        settings.dailyFoodAmount = MoneyFormat.parse(request.dailyFoodText) ?? 0
        settings.apartmentAmount = MoneyFormat.parse(request.apartmentText) ?? 0
        settings.billsAmount = MoneyFormat.parse(request.billsText) ?? 0
        settings.foodCategoryId = request.foodCategoryId
        settings.apartmentCategoryId = request.apartmentCategoryId
        settings.billsCategoryId = request.billsCategoryId
        worker.saveSettings(settings)
        // No reload: the view already shows what the user typed.
    }

    func addCategory(request: Settings.AddCategory.Request) {
        let name = request.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        worker.addCategory(name: name)
        load(request: .init())
    }

    func renameCategory(request: Settings.RenameCategory.Request) {
        let name = request.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        worker.renameCategory(id: request.id, name: name)
    }

    private struct DeletedJar {
        let category: BudgetCategory
        let transactions: [MoneyTransaction]
        let wasFood: Bool
        let wasApartment: Bool
        let wasBills: Bool
    }
    private var lastDeleted: DeletedJar?

    func deleteCategory(request: Settings.DeleteCategory.Request) {
        if let category = worker.category(id: request.id) {
            let settings = worker.settings()
            lastDeleted = DeletedJar(
                category: category,
                transactions: worker.transactions(categoryId: request.id),
                wasFood: settings.foodCategoryId == request.id,
                wasApartment: settings.apartmentCategoryId == request.id,
                wasBills: settings.billsCategoryId == request.id
            )
        }
        worker.deleteCategory(id: request.id)
        load(request: .init())
    }

    func undoDeleteCategory() {
        guard let deleted = lastDeleted else { return }
        lastDeleted = nil
        worker.restoreCategory(deleted.category, transactions: deleted.transactions,
                               wasFood: deleted.wasFood, wasApartment: deleted.wasApartment,
                               wasBills: deleted.wasBills)
        load(request: .init())
    }

    func moveCategory(request: Settings.MoveCategory.Request) {
        worker.moveCategories(from: request.from, to: request.to)
        load(request: .init())
    }
}
