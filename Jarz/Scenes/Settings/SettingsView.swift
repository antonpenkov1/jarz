import SwiftUI

protocol SettingsDisplayLogic: AnyObject {
    func displaySettings(viewModel: Settings.Load.ViewModel)
}

final class SettingsViewStore: ObservableObject, SettingsDisplayLogic {
    @Published var currencySymbol = ""
    @Published var dailyFoodText = ""
    @Published var apartmentText = ""
    @Published var billsText = ""
    @Published var foodCategoryId: UUID?
    @Published var apartmentCategoryId: UUID?
    @Published var billsCategoryId: UUID?
    @Published var categories: [Settings.Load.ViewModel.CategoryForm] = []
    @Published var newCategoryName = ""
    @Published var pendingDeleteId: UUID?

    var interactor: SettingsBusinessLogic?
    private var isLoaded = false

    func displaySettings(viewModel: Settings.Load.ViewModel) {
        isLoaded = false
        currencySymbol = viewModel.currencySymbol
        dailyFoodText = viewModel.dailyFoodText
        apartmentText = viewModel.apartmentText
        billsText = viewModel.billsText
        foodCategoryId = viewModel.foodCategoryId
        apartmentCategoryId = viewModel.apartmentCategoryId
        billsCategoryId = viewModel.billsCategoryId
        categories = viewModel.categories
        isLoaded = true
    }

    func persistSettings() {
        guard isLoaded else { return }
        interactor?.saveSettings(request: .init(
            currencySymbol: currencySymbol,
            dailyFoodText: dailyFoodText,
            apartmentText: apartmentText,
            billsText: billsText,
            foodCategoryId: foodCategoryId,
            apartmentCategoryId: apartmentCategoryId,
            billsCategoryId: billsCategoryId
        ))
    }

    func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.categories.first { $0.id == id }?.name ?? "" },
            set: { newValue in
                guard let index = self.categories.firstIndex(where: { $0.id == id }) else { return }
                self.categories[index].name = newValue
                self.interactor?.renameCategory(request: .init(id: id, name: newValue))
            }
        )
    }

    func addCategory() {
        interactor?.addCategory(request: .init(name: newCategoryName))
        newCategoryName = ""
    }

    var monthlyFoodHint: String? {
        guard let daily = MoneyFormat.parse(dailyFoodText), daily > 0 else { return nil }
        let monthly = daily * Decimal(AppSettings.foodHorizonDays)
        return "On income day: \(MoneyFormat.amount(daily)) × \(AppSettings.foodHorizonDays) = \(MoneyFormat.money(monthly, symbol: currencySymbol))"
    }
}

enum SettingsConfigurator {
    static func makeView() -> SettingsView {
        let store = SettingsViewStore()
        let presenter = SettingsPresenter()
        presenter.view = store
        store.interactor = SettingsInteractor(presenter: presenter)
        return SettingsView(store: store)
    }
}

struct SettingsView: View {
    @StateObject private var store: SettingsViewStore
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init(store: SettingsViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    EmptyView()
                } header: {
                    SectionLabel("Settings")
                        .padding(.leading, -8)
                }
                .listRowBackground(Theme.bg)

                section("Food budget") {
                    categoryPicker("Food jar", selection: $store.foodCategoryId)
                    amountRow("Per day", text: $store.dailyFoodText)
                    if let hint = store.monthlyFoodHint {
                        Text(hint.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accent)
                    }
                }

                section("Apartment") {
                    categoryPicker("Apartment jar", selection: $store.apartmentCategoryId)
                    amountRow("Per month", text: $store.apartmentText)
                }

                section("Bills — subscriptions, utilities") {
                    categoryPicker("Bills jar", selection: $store.billsCategoryId)
                    amountRow("Per month", text: $store.billsText)
                }

                section("Currency") {
                    TextField("Symbol (e.g. RSD, €, $)", text: $store.currencySymbol)
                        .font(.system(size: 16))
                }

                section("Appearance") {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    jarsRows
                        .listRowBackground(Theme.bg)
                        .listRowSeparatorTint(Theme.hairline)
                } header: {
                    HStack {
                        SectionLabel("Jars")
                        Spacer()
                        Button(editMode.isEditing ? "Done" : "Reorder") {
                            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(.leading, -8)
                    .padding(.top, 8)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .keyboardDoneButton()
            .environment(\.editMode, $editMode)
            .onAppear { store.interactor?.load(request: .init()) }
            .onChange(of: store.currencySymbol) { store.persistSettings() }
            .onChange(of: store.dailyFoodText) { store.persistSettings() }
            .onChange(of: store.apartmentText) { store.persistSettings() }
            .onChange(of: store.billsText) { store.persistSettings() }
            .onChange(of: store.foodCategoryId) { store.persistSettings() }
            .onChange(of: store.apartmentCategoryId) { store.persistSettings() }
            .onChange(of: store.billsCategoryId) { store.persistSettings() }
            .alert(
                "Delete jar?",
                isPresented: Binding(
                    get: { store.pendingDeleteId != nil },
                    set: { if !$0 { store.pendingDeleteId = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let id = store.pendingDeleteId {
                        store.interactor?.deleteCategory(request: .init(id: id))
                    }
                    store.pendingDeleteId = nil
                }
                Button("Cancel", role: .cancel) { store.pendingDeleteId = nil }
            } message: {
                Text("The jar and its whole history will be removed.")
            }
        }
        .tint(Theme.ink)
    }

    @State private var editMode: EditMode = .inactive

    @ViewBuilder
    private var jarsRows: some View {
                    ForEach(store.categories) { category in
                        TextField("Name", text: store.nameBinding(for: category.id))
                            .font(.system(size: 16))
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            store.pendingDeleteId = store.categories[index].id
                        }
                    }
                    .onMove { from, to in
                        store.interactor?.moveCategory(request: .init(from: from, to: to))
                    }
                    HStack {
                        TextField("New jar", text: $store.newCategoryName)
                            .font(.system(size: 16))
                        Button {
                            store.addCategory()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .disabled(store.newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
                .listRowBackground(Theme.bg)
                .listRowSeparatorTint(Theme.hairline)
        } header: {
            SectionLabel(title)
                .padding(.leading, -8)
                .padding(.top, 8)
        }
    }

    private func amountRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
            Spacer()
            TextField("0", text: text)
                .font(Theme.serif(17))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }

    private func categoryPicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(UUID?.none)
            ForEach(store.categories) { category in
                Text(category.name).tag(UUID?.some(category.id))
            }
        }
        .font(.system(size: 16))
        .tint(Theme.secondary)
    }
}
