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

    init(store: SettingsViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food budget") {
                    categoryPicker("Food category", selection: $store.foodCategoryId)
                    HStack {
                        Text("Per day")
                        Spacer()
                        TextField("0", text: $store.dailyFoodText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    if let hint = store.monthlyFoodHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                Section("Apartment") {
                    categoryPicker("Apartment category", selection: $store.apartmentCategoryId)
                    HStack {
                        Text("Per month")
                        Spacer()
                        TextField("0", text: $store.apartmentText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                }
                Section("Bills (subscriptions, utilities…)") {
                    categoryPicker("Bills category", selection: $store.billsCategoryId)
                    HStack {
                        Text("Per month")
                        Spacer()
                        TextField("0", text: $store.billsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                }
                Section("Currency") {
                    TextField("Symbol (e.g. RSD, €, $)", text: $store.currencySymbol)
                }
                Section("Categories") {
                    ForEach(store.categories) { category in
                        TextField("Name", text: store.nameBinding(for: category.id))
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
                        TextField("New category", text: $store.newCategoryName)
                        Button {
                            store.addCategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(store.newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .onAppear { store.interactor?.load(request: .init()) }
            .onChange(of: store.currencySymbol) { store.persistSettings() }
            .onChange(of: store.dailyFoodText) { store.persistSettings() }
            .onChange(of: store.apartmentText) { store.persistSettings() }
            .onChange(of: store.billsText) { store.persistSettings() }
            .onChange(of: store.foodCategoryId) { store.persistSettings() }
            .onChange(of: store.apartmentCategoryId) { store.persistSettings() }
            .onChange(of: store.billsCategoryId) { store.persistSettings() }
            .alert(
                "Delete category?",
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
                Text("The category and its whole history will be removed.")
            }
        }
    }

    private func categoryPicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(UUID?.none)
            ForEach(store.categories) { category in
                Text(category.name).tag(UUID?.some(category.id))
            }
        }
    }
}
