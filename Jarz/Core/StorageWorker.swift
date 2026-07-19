import Foundation
import CoreData
import SwiftData

// MARK: - SwiftData models
// CloudKit rules: every attribute needs a default, no unique constraints.
// Value-type DTOs from Models.swift stay as the currency between layers;
// interactors never touch these classes directly.

@Model
final class JarCategory {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0

    init(id: UUID = UUID(), name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }
}

@Model
final class JarTransaction {
    var id: UUID = UUID()
    var categoryId: UUID = UUID()
    var kindRaw: String = TransactionKind.expense.rawValue
    var amount: Decimal = 0
    var note: String = ""
    var date: Date = Date()

    var kind: TransactionKind { TransactionKind(rawValue: kindRaw) ?? .expense }

    init(id: UUID = UUID(), categoryId: UUID, kind: TransactionKind,
         amount: Decimal, note: String, date: Date) {
        self.id = id
        self.categoryId = categoryId
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.note = note
        self.date = date
    }
}

@Model
final class JarSettings {
    var currencySymbol: String = "RSD"
    var foodCategoryId: UUID?
    var dailyFoodAmount: Decimal = 0
    var apartmentCategoryId: UUID?
    var apartmentAmount: Decimal = 0
    var billsCategoryId: UUID?
    var billsAmount: Decimal = 0
    /// Lets us keep the oldest record if CloudKit ever syncs in a duplicate.
    var createdAt: Date = Date()

    init() {}
}

@Model
final class JarAccount {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var order: Int = 0

    init(id: UUID = UUID(), name: String, amount: Decimal, order: Int) {
        self.id = id
        self.name = name
        self.amount = amount
        self.order = order
    }
}

// MARK: - Storage worker

/// Single source of truth. SwiftData store synced to the user's private
/// iCloud database when entitlements allow it; plain local store otherwise.
final class StorageWorker {
    static let shared = StorageWorker()

    static let stateDidChange = Notification.Name("StorageWorker.stateDidChange")

    /// iCloud sync needs a paid Apple Developer account (CloudKit entitlements).
    /// Flip to true together with CODE_SIGN_ENTITLEMENTS in project.yml.
    private static let iCloudSyncEnabled = false

    private let container: ModelContainer
    private let context: ModelContext

    private init() {
        let schema = Schema([JarCategory.self, JarTransaction.self, JarSettings.self, JarAccount.self])
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: Self.iCloudSyncEnabled ? .automatic : .none
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // No iCloud account / entitlements — fall back to a local store.
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: [config])
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        migrateFromJSONIfNeeded()
        seedIfNeeded()

        // CloudKit pushes arrive as Core Data remote-change notifications.
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { _ in
            NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
        }
    }

    // MARK: Reads (DTO snapshots)

    func sortedCategories() -> [BudgetCategory] {
        let fetch = FetchDescriptor<JarCategory>(sortBy: [SortDescriptor(\.order)])
        return ((try? context.fetch(fetch)) ?? [])
            .map { BudgetCategory(id: $0.id, name: $0.name, order: $0.order) }
    }

    func category(id: UUID) -> BudgetCategory? {
        categoryModel(id: id).map { BudgetCategory(id: $0.id, name: $0.name, order: $0.order) }
    }

    func settings() -> AppSettings {
        guard let model = settingsModel() else { return AppSettings() }
        return AppSettings(
            currencySymbol: model.currencySymbol,
            foodCategoryId: model.foodCategoryId,
            dailyFoodAmount: model.dailyFoodAmount,
            apartmentCategoryId: model.apartmentCategoryId,
            apartmentAmount: model.apartmentAmount,
            billsCategoryId: model.billsCategoryId,
            billsAmount: model.billsAmount
        )
    }

    /// Newest first.
    func transactions(categoryId: UUID) -> [MoneyTransaction] {
        let fetch = FetchDescriptor<JarTransaction>(
            predicate: #Predicate { $0.categoryId == categoryId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return ((try? context.fetch(fetch)) ?? []).map(Self.dto)
    }

    func transaction(id: UUID) -> MoneyTransaction? {
        transactionModel(id: id).map(Self.dto)
    }

    func balance(of categoryId: UUID) -> Decimal {
        transactions(categoryId: categoryId)
            .reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    func totalBalance() -> Decimal {
        let ids = Set(sortedCategories().map(\.id))
        let all = (try? context.fetch(FetchDescriptor<JarTransaction>())) ?? []
        return all
            .filter { ids.contains($0.categoryId) }
            .reduce(Decimal.zero) { $0 + ($1.kind == .expense ? -$1.amount : $1.amount) }
    }

    func spentToday(categoryId: UUID) -> Decimal {
        let calendar = Calendar.current
        return transactions(categoryId: categoryId)
            .filter { $0.kind == .expense && calendar.isDateInToday($0.date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func accounts() -> [ReconciliationAccount] {
        let fetch = FetchDescriptor<JarAccount>(sortBy: [SortDescriptor(\.order)])
        return ((try? context.fetch(fetch)) ?? [])
            .map { ReconciliationAccount(id: $0.id, name: $0.name, amount: $0.amount) }
    }

    // MARK: Writes

    func addTransaction(categoryId: UUID, kind: TransactionKind, amount: Decimal, note: String, date: Date) {
        context.insert(JarTransaction(categoryId: categoryId, kind: kind, amount: amount, note: note, date: date))
        save()
    }

    func updateTransaction(id: UUID, kind: TransactionKind, amount: Decimal, note: String) {
        guard let model = transactionModel(id: id) else { return }
        model.kindRaw = kind.rawValue
        model.amount = amount
        model.note = note
        save()
    }

    func deleteTransaction(id: UUID) {
        guard let model = transactionModel(id: id) else { return }
        context.delete(model)
        save()
    }

    func saveSettings(_ dto: AppSettings) {
        let model = settingsModel() ?? {
            let created = JarSettings()
            context.insert(created)
            return created
        }()
        model.currencySymbol = dto.currencySymbol
        model.foodCategoryId = dto.foodCategoryId
        model.dailyFoodAmount = dto.dailyFoodAmount
        model.apartmentCategoryId = dto.apartmentCategoryId
        model.apartmentAmount = dto.apartmentAmount
        model.billsCategoryId = dto.billsCategoryId
        model.billsAmount = dto.billsAmount
        save()
    }

    func addCategory(name: String) {
        let nextOrder = (categoryModels().map(\.order).max() ?? -1) + 1
        context.insert(JarCategory(name: name, order: nextOrder))
        save()
    }

    func renameCategory(id: UUID, name: String) {
        guard let model = categoryModel(id: id) else { return }
        model.name = name
        save()
    }

    func deleteCategory(id: UUID) {
        guard let model = categoryModel(id: id) else { return }
        let fetch = FetchDescriptor<JarTransaction>(predicate: #Predicate { $0.categoryId == id })
        for transaction in (try? context.fetch(fetch)) ?? [] {
            context.delete(transaction)
        }
        if let settings = settingsModel() {
            if settings.foodCategoryId == id { settings.foodCategoryId = nil }
            if settings.apartmentCategoryId == id { settings.apartmentCategoryId = nil }
            if settings.billsCategoryId == id { settings.billsCategoryId = nil }
        }
        context.delete(model)
        save()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        var ordered = categoryModels()
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, model) in ordered.enumerated() {
            model.order = index
        }
        save()
    }

    func replaceAccounts(_ dtos: [ReconciliationAccount]) {
        for model in (try? context.fetch(FetchDescriptor<JarAccount>())) ?? [] {
            context.delete(model)
        }
        for (index, dto) in dtos.enumerated() {
            context.insert(JarAccount(id: dto.id, name: dto.name, amount: dto.amount, order: index))
        }
        save()
    }

    // MARK: Internals

    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
    }

    private static func dto(_ model: JarTransaction) -> MoneyTransaction {
        MoneyTransaction(id: model.id, categoryId: model.categoryId, kind: model.kind,
                         amount: model.amount, note: model.note, date: model.date)
    }

    private func categoryModels() -> [JarCategory] {
        let fetch = FetchDescriptor<JarCategory>(sortBy: [SortDescriptor(\.order)])
        return (try? context.fetch(fetch)) ?? []
    }

    private func categoryModel(id: UUID) -> JarCategory? {
        let fetch = FetchDescriptor<JarCategory>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(fetch).first
    }

    private func transactionModel(id: UUID) -> JarTransaction? {
        let fetch = FetchDescriptor<JarTransaction>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(fetch).first
    }

    private func settingsModel() -> JarSettings? {
        let fetch = FetchDescriptor<JarSettings>(sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(fetch).first
    }

    /// One-time import of the pre-SwiftData JSON store.
    private func migrateFromJSONIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<JarCategory>())) ?? 0
        guard count == 0 else { return }

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jarz", isDirectory: true)
        let url = dir.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url),
              let old = try? JSONDecoder().decode(AppState.self, from: data) else { return }

        for category in old.categories {
            context.insert(JarCategory(id: category.id, name: category.name, order: category.order))
        }
        for transaction in old.transactions {
            context.insert(JarTransaction(id: transaction.id, categoryId: transaction.categoryId,
                                          kind: transaction.kind, amount: transaction.amount,
                                          note: transaction.note, date: transaction.date))
        }
        let settings = JarSettings()
        settings.currencySymbol = old.settings.currencySymbol
        settings.foodCategoryId = old.settings.foodCategoryId
        settings.dailyFoodAmount = old.settings.dailyFoodAmount
        settings.apartmentCategoryId = old.settings.apartmentCategoryId
        settings.apartmentAmount = old.settings.apartmentAmount
        settings.billsCategoryId = old.settings.billsCategoryId
        settings.billsAmount = old.settings.billsAmount
        context.insert(settings)
        for (index, account) in old.accounts.enumerated() {
            context.insert(JarAccount(id: account.id, name: account.name,
                                      amount: account.amount, order: index))
        }
        try? context.save()
        try? FileManager.default.moveItem(at: url, to: dir.appendingPathComponent("state.json.migrated"))
    }

    private func seedIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<JarCategory>())) ?? 0
        guard count == 0 else { return }

        let names = ["Food", "Apartment", "Bills", "Gifts", "Trips", "Sport",
                     "Savings", "Clothes", "Skincare", "Phone"]
        var created: [String: JarCategory] = [:]
        for (index, name) in names.enumerated() {
            let category = JarCategory(name: name, order: index)
            created[name] = category
            context.insert(category)
        }
        let settings = JarSettings()
        settings.foodCategoryId = created["Food"]?.id
        settings.apartmentCategoryId = created["Apartment"]?.id
        settings.billsCategoryId = created["Bills"]?.id
        context.insert(settings)
        try? context.save()
    }
}
