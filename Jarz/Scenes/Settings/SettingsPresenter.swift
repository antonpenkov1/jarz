import Foundation

protocol SettingsPresentationLogic {
    func presentSettings(response: Settings.Load.Response)
}

final class SettingsPresenter: SettingsPresentationLogic {
    weak var view: SettingsDisplayLogic?

    func presentSettings(response: Settings.Load.Response) {
        func amountText(_ value: Decimal) -> String {
            value == 0 ? "" : MoneyFormat.amount(value).replacingOccurrences(of: " ", with: "")
        }
        let viewModel = Settings.Load.ViewModel(
            currencySymbol: response.settings.currencySymbol,
            dailyFoodText: amountText(response.settings.dailyFoodAmount),
            apartmentText: amountText(response.settings.apartmentAmount),
            billsText: amountText(response.settings.billsAmount),
            foodCategoryId: response.settings.foodCategoryId,
            apartmentCategoryId: response.settings.apartmentCategoryId,
            billsCategoryId: response.settings.billsCategoryId,
            categories: response.categories.map { .init(id: $0.id, name: $0.name) }
        )
        view?.displaySettings(viewModel: viewModel)
    }
}
