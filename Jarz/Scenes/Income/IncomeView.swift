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
    @FocusState private var salaryFocused: Bool

    init(store: IncomeViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Income")
                        .padding(.top, 20)

                    SectionLabel("Salary received")
                        .padding(.top, 36)
                    TextField("0", text: $store.salaryText)
                        .font(Theme.serif(52, .regular))
                        .keyboardType(.decimalPad)
                        .focused($salaryFocused)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)
                    Hairline()

                    SectionLabel("Distribute")
                        .padding(.top, 40)
                        .padding(.bottom, 4)

                    ForEach(store.viewModel.rows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Theme.ink)
                                if let hint = row.autoHint {
                                    Text(hint.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.2)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            Spacer()
                            TextField("0", text: store.binding(for: row.id))
                                .font(Theme.serif(18))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: 130)
                        }
                        .padding(.vertical, 15)
                        Hairline()
                    }

                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("Allocated")
                        Spacer()
                        AmountText(text: MoneyFormat.money(store.allocatedTotal, symbol: store.viewModel.currencySymbol))
                    }
                    .padding(.top, 28)

                    if let remaining = store.remaining {
                        HStack(alignment: .firstTextBaseline) {
                            SectionLabel("Left to allocate")
                            Spacer()
                            AmountText(
                                text: MoneyFormat.money(remaining, symbol: store.viewModel.currencySymbol),
                                color: remaining == 0 ? Theme.accent : (remaining < 0 ? Theme.negative : Theme.ink)
                            )
                        }
                        .padding(.top, 14)
                    }

                    CapsuleButton(title: "Add to balances", disabled: store.allocatedTotal <= 0) {
                        store.interactor?.save(request: .init(amounts: store.amounts))
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
            .onAppear {
                store.interactor?.prepare(request: .init())
                #if DEBUG
                // Screenshot hook: `-FocusSalary 1` opens the keyboard right away.
                if UserDefaults.standard.bool(forKey: "FocusSalary") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { salaryFocused = true }
                }
                #endif
            }
            .alert("Done", isPresented: Binding(
                get: { store.successMessage != nil },
                set: { if !$0 { store.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.successMessage ?? "")
            }
        }
        .tint(Theme.ink)
    }
}
