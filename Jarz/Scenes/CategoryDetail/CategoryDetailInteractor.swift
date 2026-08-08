import Foundation

protocol CategoryDetailBusinessLogic {
    func load(request: CategoryDetail.Load.Request)
    func saveTransaction(request: CategoryDetail.SaveTransaction.Request)
    func deleteTransaction(request: CategoryDetail.DeleteTransaction.Request)
    func undoDeleteTransaction()
    func setGoal(request: CategoryDetail.SetGoal.Request)
}

final class CategoryDetailInteractor: CategoryDetailBusinessLogic {
    private let presenter: CategoryDetailPresentationLogic
    private let worker: StorageWorker
    private let categoryId: UUID

    init(categoryId: UUID, presenter: CategoryDetailPresentationLogic, worker: StorageWorker = .shared) {
        self.categoryId = categoryId
        self.presenter = presenter
        self.worker = worker
    }

    func setGoal(request: CategoryDetail.SetGoal.Request) {
        worker.setGoal(categoryId: categoryId, amount: request.amount, date: request.date)
        load(request: .init())
    }

    private var lastDeleted: MoneyTransaction?

    func undoDeleteTransaction() {
        guard let dto = lastDeleted else { return }
        lastDeleted = nil
        worker.restoreTransaction(dto)
        load(request: .init())
    }

    func load(request: CategoryDetail.Load.Request) {
        guard let category = worker.category(id: categoryId) else { return }
        let settings = worker.settings()
        let response = CategoryDetail.Load.Response(
            category: category,
            balance: worker.balance(of: categoryId),
            isFoodCategory: settings.foodCategoryId == categoryId && settings.dailyFoodAmount > 0,
            dailyFoodAmount: settings.dailyFoodAmount,
            foodPlanEnd: settings.foodPlanEnd,
            transactions: worker.transactions(categoryId: categoryId),
            currencySymbol: settings.currencySymbol
        )
        presenter.presentDetail(response: response)
    }

    func saveTransaction(request: CategoryDetail.SaveTransaction.Request) {
        guard let amount = MoneyFormat.parse(request.amountText), amount > 0 else { return }
        if let id = request.transactionId, let existing = worker.transaction(id: id) {
            // Preserve `.allocation` on income rows created by the Income
            // screen; only flip the kind when the direction changes.
            let kind: TransactionKind
            if request.isExpense {
                kind = .expense
            } else if existing.kind == .expense {
                kind = .topUp
            } else {
                kind = existing.kind
            }
            worker.updateTransaction(id: id, kind: kind, amount: amount, note: request.note)
        } else {
            worker.addTransaction(
                categoryId: categoryId,
                kind: request.isExpense ? .expense : .topUp,
                amount: amount,
                note: request.note,
                date: Date()
            )
        }
        load(request: .init())
    }

    func deleteTransaction(request: CategoryDetail.DeleteTransaction.Request) {
        lastDeleted = worker.transaction(id: request.transactionId)
        worker.deleteTransaction(id: request.transactionId)
        load(request: .init())
    }
}
