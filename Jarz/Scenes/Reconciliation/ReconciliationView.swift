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

    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Revision")
                        .padding(.top, 20)

                    Text("Count the money on every card and in cash, then compare with the plan.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 14)

                    SectionLabel("Cards & cash")
                        .padding(.top, 36)
                        .padding(.bottom, 4)

                    ForEach($store.accounts) { $account in
                        HStack(spacing: 14) {
                            TextField("Name (e.g. Visa, Cash)", text: $account.name)
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.ink)
                            TextField("0", text: $account.amountText)
                                .font(Theme.serif(18))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: 110)
                            Button {
                                store.removeAccount(id: account.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .padding(.vertical, 15)
                        Hairline()
                    }

                    Button {
                        store.addAccount()
                    } label: {
                        Text("+ Add card or cash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 18)

                    SectionLabel("Result")
                        .padding(.top, 40)

                    resultRow("Planned in app", store.appTotalText, color: Theme.ink)
                        .padding(.top, 16)
                    resultRow("Counted for real",
                              MoneyFormat.money(store.countedTotal, symbol: store.currencySymbol),
                              color: Theme.ink)
                        .padding(.top, 12)
                    resultRow("Difference",
                              MoneyFormat.money(store.difference, symbol: store.currencySymbol),
                              color: store.difference == 0 ? Theme.accent : Theme.negative)
                        .padding(.top, 12)

                    Group {
                        if store.difference == 0 && !store.accounts.isEmpty {
                            Text("Perfect — your plan matches reality.")
                                .foregroundStyle(Theme.accent)
                        } else if store.difference != 0 {
                            Text(store.difference > 0
                                 ? "You have more money than planned. Add the extra to a jar to zero out."
                                 : "Some money is unaccounted for. Record the missing expenses to zero out.")
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .font(.system(size: 14))
                    .padding(.top, 16)

                    CapsuleButton(title: "Save revision") {
                        store.save()
                    }
                    .padding(.top, 32)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .onAppear { store.interactor?.load(request: .init()) }
        }
        .tint(Theme.ink)
    }

    private func resultRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)
            Spacer()
            AmountText(text: value, size: 18, color: color)
        }
    }
}
