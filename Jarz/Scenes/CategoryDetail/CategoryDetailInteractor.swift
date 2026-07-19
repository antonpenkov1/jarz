import Foundation

protocol CategoryDetailBusinessLogic {
    func load(request: CategoryDetail.Load.Request)
    func saveTransaction(request: CategoryDetail.SaveTransaction.Request)
    func deleteTransaction(request: CategoryDetail.DeleteTransaction.Request)
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

    func load(request: CategoryDetail.Load.Request) {
        guard let category = worker.state.categories.first(where: { $0.id == categoryId }) else { return }
        let settings = worker.state.settings
        let transactions = worker.state.transactions
            .filter { $0.categoryId == categoryId }
            .sorted { $0.date > $1.date }
        let response = CategoryDetail.Load.Response(
            category: category,
            balance: worker.balance(of: categoryId),
            isFoodCategory: settings.foodCategoryId == categoryId && settings.dailyFoodAmount > 0,
            dailyFoodAmount: settings.dailyFoodAmount,
            transactions: transactions,
            currencySymbol: settings.currencySymbol
        )
        presenter.presentDetail(response: response)
    }

    func saveTransaction(request: CategoryDetail.SaveTransaction.Request) {
        guard let amount = MoneyFormat.parse(request.amountText), amount > 0 else { return }
        worker.update { state in
            if let id = request.transactionId,
               let index = state.transactions.firstIndex(where: { $0.id == id }) {
                var transaction = state.transactions[index]
                transaction.amount = amount
                transaction.note = request.note
                // Preserve `.allocation` on income rows created by the Income
                // screen; only flip the kind when the direction changes.
                if request.isExpense {
                    transaction.kind = .expense
                } else if transaction.kind == .expense {
                    transaction.kind = .topUp
                }
                state.transactions[index] = transaction
            } else {
                state.transactions.append(MoneyTransaction(
                    categoryId: categoryId,
                    kind: request.isExpense ? .expense : .topUp,
                    amount: amount,
                    note: request.note,
                    date: Date()
                ))
            }
        }
        load(request: .init())
    }

    func deleteTransaction(request: CategoryDetail.DeleteTransaction.Request) {
        worker.update { state in
            state.transactions.removeAll { $0.id == request.transactionId }
        }
        load(request: .init())
    }
}
