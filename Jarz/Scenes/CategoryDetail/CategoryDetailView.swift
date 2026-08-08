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
        return CategoryDetailView(store: store, categoryId: categoryId)
    }
}

struct CategoryDetailView: View {
    @StateObject private var store: CategoryDetailViewStore
    let categoryId: UUID

    init(store: CategoryDetailViewStore, categoryId: UUID) {
        _store = StateObject(wrappedValue: store)
        self.categoryId = categoryId
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
                    if let goalLine = store.viewModel.goalLine {
                        Text(goalLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 6)
                    }
                    if !store.viewModel.days.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(store.viewModel.days) { day in
                                VStack(spacing: 4) {
                                    Text(day.weekday)
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(day.isToday ? Theme.ink : Theme.secondary)
                                    Text(day.amountText)
                                        .font(Theme.serif(13))
                                        .foregroundStyle(day.isMuted ? Theme.hairline
                                                         : (day.isToday ? Theme.ink : Theme.secondary))
                                        .strikethrough(day.isMuted, color: Theme.hairline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 18)
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
                        if row.isEditable { store.presentEditSheet(rowId: row.id) }
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
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Theme.bg)
                    .listRowSeparatorTint(Theme.hairline)
                    .listRowInsets(EdgeInsets(top: 8, leading: 28, bottom: 8, trailing: 28))
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.interactor?.deleteTransaction(request: .init(transactionId: row.id))
                            showUndoToast = true
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTransferSheet = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    goalAmountText = store.viewModel.goalAmount.map {
                        MoneyFormat.amount($0).replacingOccurrences(of: " ", with: "")
                    } ?? ""
                    goalHasDate = store.viewModel.goalDate != nil
                    goalDate = store.viewModel.goalDate
                        ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!
                    showGoalSheet = true
                } label: {
                    Image(systemName: "scope")
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .sheet(isPresented: $store.isSheetPresented) {
            transactionSheet
        }
        .undoToast(isPresented: $showUndoToast) {
            store.interactor?.undoDeleteTransaction()
        }
        .sheet(isPresented: $showGoalSheet) { goalSheet }
        .sheet(isPresented: $showTransferSheet) {
            TransferSheet(
                jars: StorageWorker.shared.sortedCategories()
                    .filter { $0.id != categoryId }
                    .map { .init(id: $0.id, name: $0.name) },
                fixedFrom: .init(id: categoryId, name: store.viewModel.title),
                onSave: { _, toId, amount in
                    store.interactor?.transfer(request: .init(toId: toId, amount: amount))
                    showTransferSheet = false
                },
                onCancel: { showTransferSheet = false }
            )
        }
        .onAppear { store.interactor?.load(request: .init()) }
    }

    @State private var showUndoToast = false
    @State private var showTransferSheet = false
    @State private var showGoalSheet = false
    @State private var goalAmountText = ""
    @State private var goalHasDate = false
    @State private var goalDate = Date()

    private var goalSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    TextField("0", text: $goalAmountText)
                        .font(Theme.serif(52, .regular))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                    Hairline()
                }

                Toggle(isOn: $goalHasDate) {
                    Text("Target date")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)

                if goalHasDate {
                    DatePicker("", selection: $goalDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                if store.viewModel.goalAmount != nil {
                    Button {
                        store.interactor?.setGoal(request: .init(amount: nil, date: nil))
                        showGoalSheet = false
                    } label: {
                        Text("Remove goal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.negative)
                    }
                }

                Spacer()
            }
            .padding(28)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showGoalSheet = false }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = MoneyFormat.parse(goalAmountText), amount > 0 {
                            store.interactor?.setGoal(request: .init(
                                amount: amount, date: goalHasDate ? goalDate : nil))
                            Haptics.success()
                        }
                        showGoalSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                    .disabled((MoneyFormat.parse(goalAmountText) ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
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

                AmountChips { value in
                    let current = MoneyFormat.parse(store.formAmount) ?? 0
                    store.formAmount = "\(NSDecimalNumber(decimal: current + value))"
                }

                TextField("Note (optional)", text: $store.formNote)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(28)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(store.editingTransactionId == nil
                ? Text("New operation") : Text("Edit operation"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.isSheetPresented = false }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.submitForm()
                        Haptics.success()
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                        .disabled(MoneyFormat.parse(store.formAmount) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
