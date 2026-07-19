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
            settings: worker.state.settings,
            categories: worker.sortedCategories()
        ))
    }

    func saveSettings(request: Settings.SaveSettings.Request) {
        worker.update { state in
            state.settings.currencySymbol = request.currencySymbol
            state.settings.dailyFoodAmount = MoneyFormat.parse(request.dailyFoodText) ?? 0
            state.settings.apartmentAmount = MoneyFormat.parse(request.apartmentText) ?? 0
            state.settings.billsAmount = MoneyFormat.parse(request.billsText) ?? 0
            state.settings.foodCategoryId = request.foodCategoryId
            state.settings.apartmentCategoryId = request.apartmentCategoryId
            state.settings.billsCategoryId = request.billsCategoryId
        }
        // No reload: the view already shows what the user typed.
    }

    func addCategory(request: Settings.AddCategory.Request) {
        let name = request.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        worker.update { state in
            let nextOrder = (state.categories.map(\.order).max() ?? -1) + 1
            state.categories.append(BudgetCategory(name: name, order: nextOrder))
        }
        load(request: .init())
    }

    func renameCategory(request: Settings.RenameCategory.Request) {
        let name = request.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        worker.update { state in
            if let index = state.categories.firstIndex(where: { $0.id == request.id }) {
                state.categories[index].name = name
            }
        }
    }

    func deleteCategory(request: Settings.DeleteCategory.Request) {
        worker.update { state in
            state.categories.removeAll { $0.id == request.id }
            state.transactions.removeAll { $0.categoryId == request.id }
            if state.settings.foodCategoryId == request.id { state.settings.foodCategoryId = nil }
            if state.settings.apartmentCategoryId == request.id { state.settings.apartmentCategoryId = nil }
            if state.settings.billsCategoryId == request.id { state.settings.billsCategoryId = nil }
        }
        load(request: .init())
    }

    func moveCategory(request: Settings.MoveCategory.Request) {
        worker.update { state in
            var ordered = state.categories.sorted { $0.order < $1.order }
            ordered.move(fromOffsets: request.from, toOffset: request.to)
            for (index, category) in ordered.enumerated() {
                if let stateIndex = state.categories.firstIndex(where: { $0.id == category.id }) {
                    state.categories[stateIndex].order = index
                }
            }
        }
        load(request: .init())
    }
}
