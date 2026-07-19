import SwiftUI

protocol ReconciliationDisplayLogic: AnyObject {
    func displayAccounts(viewModel: Reconciliation.Load.ViewModel)
}

final class ReconciliationViewStore: ObservableObject, ReconciliationDisplayLogic {
    @Published var accounts: [Reconciliation.Load.ViewModel.AccountForm] = []
    @Published var appTotal: Decimal = 0
    @Published var appTotalText = ""
    @Published var currencySymbol = ""
    var interactor: ReconciliationBusinessLogic?

    func displayAccounts(viewModel: Reconciliation.Load.ViewModel) {
        accounts = viewModel.accounts
        appTotal = viewModel.appTotal
        appTotalText = viewModel.appTotalText
        currencySymbol = viewModel.currencySymbol
    }

    var countedTotal: Decimal {
        accounts.compactMap { MoneyFormat.parse($0.amountText) }.reduce(0, +)
    }

    var difference: Decimal {
        countedTotal - appTotal
    }

    func addAccount() {
        accounts.append(.init(id: UUID(), name: "", amountText: ""))
    }

    func save() {
        interactor?.save(request: .init(entries: accounts.map {
            .init(id: $0.id, name: $0.name, amountText: $0.amountText)
        }))
    }
}

enum ReconciliationConfigurator {
    static func makeView() -> ReconciliationView {
        let store = ReconciliationViewStore()
        let presenter = ReconciliationPresenter()
        presenter.view = store
        store.interactor = ReconciliationInteractor(presenter: presenter)
        return ReconciliationView(store: store)
    }
}

struct ReconciliationView: View {
    @StateObject private var store: ReconciliationViewStore

    init(store: ReconciliationViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Count the money on every card and in cash, enter it below, and compare with what the app has planned.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Cards & cash") {
                    ForEach($store.accounts) { $account in
                        HStack {
                            TextField("Name (e.g. Visa, Cash)", text: $account.name)
                            TextField("0", text: $account.amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                    }
                    .onDelete { store.accounts.remove(atOffsets: $0) }
                    Button {
                        store.addAccount()
                    } label: {
                        Label("Add card or cash", systemImage: "plus")
                    }
                }
                Section("Result") {
                    HStack {
                        Text("Planned in app")
                        Spacer()
                        Text(store.appTotalText).fontWeight(.semibold)
                    }
                    HStack {
                        Text("Counted for real")
                        Spacer()
                        Text(MoneyFormat.money(store.countedTotal, symbol: store.currencySymbol))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Difference")
                        Spacer()
                        Text(MoneyFormat.money(store.difference, symbol: store.currencySymbol))
                            .fontWeight(.bold)
                            .foregroundStyle(store.difference == 0 ? Color.green : .red)
                    }
                    if store.difference == 0 && !store.accounts.isEmpty {
                        Text("Perfect — your plan matches reality.")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else if store.difference != 0 {
                        Text(store.difference > 0
                             ? "You have more money than planned. Add the extra to a category to zero out."
                             : "Some money is unaccounted for. Record the missing expenses to zero out.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button {
                        store.save()
                    } label: {
                        Text("Save revision")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Revision")
            .onAppear { store.interactor?.load(request: .init()) }
        }
    }
}
