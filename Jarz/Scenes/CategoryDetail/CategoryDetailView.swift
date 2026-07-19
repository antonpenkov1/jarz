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
        guard let transaction = StorageWorker.shared.transaction(id: rowId) else { return }
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
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(store.viewModel.title)
                        .padding(.top, 8)
                    Text(store.viewModel.balanceText)
                        .font(Theme.serif(56, .regular))
                        .foregroundStyle(store.viewModel.isNegative ? Theme.negative : Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.top, 8)
                    if let foodLine = store.viewModel.foodLine {
                        Text(foodLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(store.viewModel.isNegative ? Theme.negative : Theme.accent)
                            .padding(.top, 6)
                    }
                    SectionLabel("History")
                        .padding(.top, 36)
                }
                .listRowBackground(Theme.bg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 8, trailing: 28))
            }

            Section {
                if store.viewModel.rows.isEmpty {
                    Text("No operations yet")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondary)
                        .listRowBackground(Theme.bg)
                        .listRowInsets(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
                }
                ForEach(store.viewModel.rows) { row in
                    Button {
                        store.presentEditSheet(rowId: row.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                if !row.note.isEmpty {
                                    Text(row.note)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.ink)
                                }
                                if !row.kindLabel.isEmpty {
                                    Text(row.kindLabel.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Theme.accent)
                                }
                                Text(row.dateText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            AmountText(text: row.amountText,
                                       color: row.isExpense ? Theme.ink : Theme.accent)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Theme.bg)
                    .listRowSeparatorTint(Theme.hairline)
                    .listRowInsets(EdgeInsets(top: 8, leading: 28, bottom: 8, trailing: 28))
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.interactor?.deleteTransaction(request: .init(transactionId: row.id))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.presentAddSheet()
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
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
            VStack(spacing: 28) {
                Picker("Type", selection: $store.formIsExpense) {
                    Text("Expense").tag(true)
                    Text("Money in").tag(false)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    TextField("0", text: $store.formAmount)
                        .font(Theme.serif(52, .regular))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                    Hairline()
                }

                TextField("Note (optional)", text: $store.formNote)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(28)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(store.editingTransactionId == nil ? "New operation" : "Edit operation")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.isSheetPresented = false }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.submitForm() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                        .disabled(MoneyFormat.parse(store.formAmount) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
