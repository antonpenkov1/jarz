import Foundation

protocol SettingsBusinessLogic {
    func load(request: Settings.Load.Request)
    func saveSettings(request: Settings.SaveSettings.Request)
    func addCategory(request: Settings.AddCategory.Request)
    func renameCategory(request: Settings.RenameCategory.Request)
    func deleteCategory(request: Settings.DeleteCategory.Request)
    func moveCategory(request: Settings.MoveCategory.Request)
}

final class SettingsInteractor: SettingsBusinessLogic {
    private let presenter: SettingsPresentationLogic
    private let worker: StorageWorker

    init(presenter: SettingsPresentationLogic, worker: StorageWorker = .shared) {
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

    func deleteCategory(request: Settings.DeleteCategory.Request) {
        worker.deleteCategory(id: request.id)
        load(request: .init())
    }

    func moveCategory(request: Settings.MoveCategory.Request) {
        worker.moveCategories(from: request.from, to: request.to)
        load(request: .init())
    }
}
