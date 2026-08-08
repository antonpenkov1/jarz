import SwiftUI

/// Monthly bills that log themselves. Deliberately worker-backed and simple:
/// a settings sub-screen, not a full VIP scene.
struct RecurringSheet: View {
    let onDone: () -> Void

    @State private var recurrings: [RecurringPayment] = []
    @State private var categories: [BudgetCategory] = []
    @State private var newName = ""
    @State private var newAmountText = ""
    @State private var newCategoryId: UUID?
    @State private var newDay = 1

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if recurrings.isEmpty {
                        Text("Nothing yet — add your first monthly bill below.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                            .listRowBackground(Theme.bg)
                    }
                    ForEach(recurrings) { recurring in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(recurring.name)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.ink)
                                Text(String(localized: "Every month on day \(recurring.dayOfMonth) · \(jarName(recurring.categoryId))"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            AmountText(text: MoneyFormat.amount(recurring.amount), size: 16)
                        }
                        .listRowBackground(Theme.bg)
                        .listRowSeparatorTint(Theme.hairline)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                StorageWorker.shared.deleteRecurring(id: recurring.id)
                                reload()
                            }
                        }
                    }
                } header: {
                    SectionLabel("Recurring payments")
                        .padding(.leading, -8)
                }

                Section {
                    TextField("Name (e.g. Spotify)", text: $newName)
                        .font(.system(size: 16))
                    HStack {
                        Text("Amount")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        TextField("0", text: $newAmountText)
                            .font(Theme.serif(17))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    Picker("Jar", selection: $newCategoryId) {
                        ForEach(categories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }
                    .font(.system(size: 16))
                    .tint(Theme.secondary)
                    Picker("Day of month", selection: $newDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .font(.system(size: 16))
                    .tint(Theme.secondary)
                    Button {
                        addRecurring()
                    } label: {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(canAdd ? Theme.accent : Theme.secondary)
                    }
                    .disabled(!canAdd)
                } header: {
                    SectionLabel("New recurring payment")
                        .padding(.leading, -8)
                        .padding(.top, 8)
                }
                .listRowBackground(Theme.bg)
                .listRowSeparatorTint(Theme.hairline)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .keyboardDoneButton()
            .navigationTitle("Recurring payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                }
            }
            .onAppear { reload() }
        }
    }

    private var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
            && (MoneyFormat.parse(newAmountText) ?? 0) > 0
            && newCategoryId != nil
    }

    private func jarName(_ id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? ""
    }

    private func reload() {
        recurrings = StorageWorker.shared.recurrings()
        categories = StorageWorker.shared.sortedCategories()
        if newCategoryId == nil { newCategoryId = categories.first?.id }
    }

    private func addRecurring() {
        guard let amount = MoneyFormat.parse(newAmountText), let categoryId = newCategoryId else { return }
        StorageWorker.shared.addRecurring(
            name: newName.trimmingCharacters(in: .whitespaces),
            amount: amount, categoryId: categoryId, dayOfMonth: newDay)
        newName = ""
        newAmountText = ""
        Haptics.success()
        reload()
    }
}
