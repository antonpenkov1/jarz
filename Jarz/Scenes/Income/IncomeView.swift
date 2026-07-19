import SwiftUI

protocol IncomeDisplayLogic: AnyObject {
    func displayPrepared(viewModel: Income.Prepare.ViewModel)
    func displaySaved(viewModel: Income.Save.ViewModel)
}

final class IncomeViewStore: ObservableObject, IncomeDisplayLogic {
    @Published var viewModel: Income.Prepare.ViewModel = .empty
    @Published var salaryText = ""
    @Published var amounts: [UUID: String] = [:]
    @Published var successMessage: String?
    var interactor: IncomeBusinessLogic?

    func displayPrepared(viewModel: Income.Prepare.ViewModel) {
        self.viewModel = viewModel
        amounts = Dictionary(uniqueKeysWithValues: viewModel.rows.map { ($0.id, $0.prefillText) })
    }

    func displaySaved(viewModel: Income.Save.ViewModel) {
        successMessage = viewModel.message
        salaryText = ""
    }

    var allocatedTotal: Decimal {
        amounts.values.compactMap(MoneyFormat.parse).reduce(0, +)
    }

    var remaining: Decimal? {
        guard let salary = MoneyFormat.parse(salaryText) else { return nil }
        return salary - allocatedTotal
    }

    func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.amounts[id] ?? "" },
            set: { self.amounts[id] = $0 }
        )
    }
}

enum IncomeConfigurator {
    static func makeView() -> IncomeView {
        let store = IncomeViewStore()
        let presenter = IncomePresenter()
        presenter.view = store
        store.interactor = IncomeInteractor(presenter: presenter)
        return IncomeView(store: store)
    }
}

struct IncomeView: View {
    @StateObject private var store: IncomeViewStore

    init(store: IncomeViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Salary received") {
                    TextField("Total amount (optional)", text: $store.salaryText)
                        .keyboardType(.decimalPad)
                }
                Section("Distribute across categories") {
                    ForEach(store.viewModel.rows) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                if let hint = row.autoHint {
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Spacer()
                            TextField("0", text: store.binding(for: row.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 140)
                        }
                    }
                }
                Section {
                    HStack {
                        Text("Allocated")
                        Spacer()
                        Text(MoneyFormat.money(store.allocatedTotal, symbol: store.viewModel.currencySymbol))
                            .fontWeight(.semibold)
                    }
                    if let remaining = store.remaining {
                        HStack {
                            Text("Left to allocate")
                            Spacer()
                            Text(MoneyFormat.money(remaining, symbol: store.viewModel.currencySymbol))
                                .fontWeight(.semibold)
                                .foregroundStyle(remaining == 0 ? Color.green : (remaining < 0 ? .red : .orange))
                        }
                    }
                }
                Section {
                    Button {
                        store.interactor?.save(request: .init(amounts: store.amounts))
                    } label: {
                        Text("Add to balances")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(store.allocatedTotal <= 0)
                }
            }
            .navigationTitle("Income")
            .onAppear { store.interactor?.prepare(request: .init()) }
            .alert("Done", isPresented: Binding(
                get: { store.successMessage != nil },
                set: { if !$0 { store.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.successMessage ?? "")
            }
        }
    }
}
