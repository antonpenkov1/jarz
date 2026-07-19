import SwiftUI

protocol ReconciliationDisplayLogic: AnyObject {
    func displayAccounts(viewModel: Reconciliation.Load.ViewModel)
}

final class ReconciliationViewStore: ObservableObject, ReconciliationDisplayLogic {
    @Published var accounts: [Reconciliation.Load.ViewModel.AccountForm] = []
    @Published var appTotal: Decimal = 0
    @Published var appTotalText = ""
    @Published var currencySymbol = ""
    @Published var revisions: [Reconciliation.Load.ViewModel.RevisionRow] = []
    var interactor: ReconciliationBusinessLogic?

    func displayAccounts(viewModel: Reconciliation.Load.ViewModel) {
        accounts = viewModel.accounts
        appTotal = viewModel.appTotal
        appTotalText = viewModel.appTotalText
        currencySymbol = viewModel.currencySymbol
        revisions = viewModel.revisions
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

                    if !store.revisions.isEmpty {
                        SectionLabel("History")
                            .padding(.top, 44)
                            .padding(.bottom, 4)

                        ForEach(store.revisions) { revision in
                            revisionRow(revision)
                            Hairline()
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .onAppear {
                store.interactor?.load(request: .init())
                #if DEBUG
                // Screenshot hook: `-DemoRevision 1` saves a demo revision through the real path.
                if UserDefaults.standard.bool(forKey: "DemoRevision") {
                    store.interactor?.save(request: .init(entries: [
                        .init(id: UUID(), name: "Visa", amountText: "120000"),
                        .init(id: UUID(), name: "Cash", amountText: "21300"),
                    ]))
                }
                #endif
            }
        }
        .tint(Theme.ink)
    }

    @State private var expandedRevisions: Set<UUID> = []

    @ViewBuilder
    private func revisionRow(_ revision: Reconciliation.Load.ViewModel.RevisionRow) -> some View {
        let isExpanded = expandedRevisions.contains(revision.id)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if isExpanded {
                        expandedRevisions.remove(revision.id)
                    } else {
                        expandedRevisions.insert(revision.id)
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(revision.dateText)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    AmountText(text: revision.differenceText, size: 16,
                               color: revision.isBalanced ? Theme.accent : Theme.negative)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow("Planned in app", revision.plannedText)
                    detailRow("Counted for real", revision.countedText)
                    ForEach(revision.entries) { entry in
                        detailRow(entry.name, entry.amountText)
                            .padding(.leading, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .contextMenu {
            Button("Delete revision", role: .destructive) {
                store.interactor?.deleteRevision(request: .init(id: revision.id))
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
            Spacer()
            AmountText(text: value, size: 15, color: Theme.secondary)
        }
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
