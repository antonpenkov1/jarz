import SwiftUI

protocol CategoryDetailDisplayLogic: AnyObject {
    func displayDetail(viewModel: CategoryDetail.Load.ViewModel)
}

final class CategoryDetailViewStore: ObservableObject, CategoryDetailDisplayLogic {
    @Published var viewModel: CategoryDetail.Load.ViewModel = .empty
    var interactor: CategoryDetailBusinessLogic?

    // Add/edit sheet state
    @Published var isSheetPresented = false
    @Published var editingTransactionId: UUID?
    @Published var formIsExpense = true
    @Published var formAmount = ""
    @Published var formNote = ""

    func displayDetail(viewModel: CategoryDetail.Load.ViewModel) {
        self.viewModel = viewModel
    }

    func presentAddSheet() {
        editingTransactionId = nil
        formIsExpense = true
        formAmount = ""
        formNote = ""
        isSheetPresented = true
    }

    func presentEditSheet(rowId: UUID) {
        guard let transaction = StorageWorker.shared.state.transactions
            .first(where: { $0.id == rowId }) else { return }
        editingTransactionId = rowId
        formIsExpense = transaction.kind == .expense
        formAmount = MoneyFormat.amount(transaction.amount).replacingOccurrences(of: " ", with: "")
        formNote = transaction.note
        isSheetPresented = true
    }

    func submitForm() {
        interactor?.saveTransaction(request: .init(
            transactionId: editingTransactionId,
            isExpense: formIsExpense,
            amountText: formAmount,
            note: formNote
        ))
        isSheetPresented = false
    }
}

enum CategoryDetailConfigurator {
    static func makeView(categoryId: UUID) -> CategoryDetailView {
        let store = CategoryDetailViewStore()
        let presenter = CategoryDetailPresenter()
        presenter.view = store
        store.interactor = CategoryDetailInteractor(categoryId: categoryId, presenter: presenter)
        return CategoryDetailView(store: store)
    }
}

struct CategoryDetailView: View {
    @StateObject private var store: CategoryDetailViewStore

    init(store: CategoryDetailViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.viewModel.balanceText)
                        .font(.largeTitle.bold())
                        .foregroundStyle(store.viewModel.isNegative ? .red : .primary)
                    if let foodLine = store.viewModel.foodLine {
                        Text(foodLine)
                            .font(.subheadline)
                            .foregroundStyle(store.viewModel.isNegative ? .red : .green)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("History") {
                if store.viewModel.rows.isEmpty {
                    Text("No operations yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.viewModel.rows) { row in
                    Button {
                        store.presentEditSheet(rowId: row.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if !row.note.isEmpty {
                                    Text(row.note)
                                }
                                if !row.kindLabel.isEmpty {
                                    Text(row.kindLabel)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text(row.dateText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(row.amountText)
                                .fontWeight(.semibold)
                                .foregroundStyle(row.isExpense ? .primary : Color.green)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.interactor?.deleteTransaction(request: .init(transactionId: row.id))
                        }
                    }
                }
            }
        }
        .navigationTitle(store.viewModel.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.presentAddSheet()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $store.isSheetPresented) {
            transactionSheet
        }
        .onAppear { store.interactor?.load(request: .init()) }
    }

    private var transactionSheet: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $store.formIsExpense) {
                    Text("Expense").tag(true)
                    Text("Money in").tag(false)
                }
                .pickerStyle(.segmented)
                TextField("Amount", text: $store.formAmount)
                    .keyboardType(.decimalPad)
                TextField("Note (optional)", text: $store.formNote)
            }
            .navigationTitle(store.editingTransactionId == nil ? "New operation" : "Edit operation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.isSheetPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.submitForm() }
                        .disabled(MoneyFormat.parse(store.formAmount) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
