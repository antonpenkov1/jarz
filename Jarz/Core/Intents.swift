import AppIntents
import Foundation

/// Logs an expense to the food jar. Powers the widget buttons and Siri.
struct LogFoodExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log food expense"
    static var description = IntentDescription("Adds an expense to your food jar.")

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend on food?")
    var amount: Double

    init() {}

    init(amount: Double) {
        self.amount = amount
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let amount = self.amount
        let dialogText = await MainActor.run { () -> String in
            let worker = StorageWorker.shared
            let settings = worker.settings()
            guard let foodId = settings.foodCategoryId, amount > 0 else {
                return String(localized: "Set a daily food budget in Settings")
            }
            worker.addTransaction(categoryId: foodId, kind: .expense,
                                  amount: Decimal(amount), note: "", date: Date())
            let money = MoneyFormat.money(Decimal(amount), symbol: settings.currencySymbol)
            return String(localized: "Logged \(money) on food.")
        }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

/// Answers "how much is left for food today".
struct FoodLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Food left today"
    static var description = IntentDescription("Tells you what's left to spend on food today.")

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialogText = await MainActor.run { () -> String in
            let worker = StorageWorker.shared
            let settings = worker.settings()
            guard let foodId = settings.foodCategoryId, settings.dailyFoodAmount > 0,
                  let plan = FoodMath.plan(balance: worker.balance(of: foodId),
                                           daily: settings.dailyFoodAmount,
                                           planEnd: settings.foodPlanEnd) else {
                return String(localized: "Set a daily food budget in Settings")
            }
            let money = MoneyFormat.money(max(0, plan.available), symbol: settings.currencySymbol)
            return String(localized: "Left for today: \(money)")
        }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
