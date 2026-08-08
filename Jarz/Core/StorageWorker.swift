import Foundation
import CoreData
import SwiftData
import WidgetKit

// MARK: - SwiftData models
// CloudKit rules: every attribute needs a default, no unique constraints.
// Value-type DTOs from Models.swift stay as the currency between layers;
// interactors never touch these classes directly.

@Model
final class JarCategory {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    var goalAmount: Decimal?
    var goalDate: Date?

    init(id: UUID = UUID(), name: String, order: Int,
         goalAmount: Decimal? = nil, goalDate: Date? = nil) {
        self.id = id
        self.name = name
        self.order = order
        self.goalAmount = goalAmount
        self.goalDate = goalDate
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
    var foodPlanEnd: Date?
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

@Model
final class JarRevision {
    var id: UUID = UUID()
    var date: Date = Date()
    var planned: Decimal = 0
    var counted: Decimal = 0
    /// JSON-encoded [RevisionEntry] — per-account snapshot at save time.
    var entriesData: Data = Data()

    init(id: UUID = UUID(), date: Date, planned: Decimal, counted: Decimal, entriesData: Data) {
        self.id = id
        self.date = date
        self.planned = planned
        self.counted = counted
        self.entriesData = entriesData
    }
}

// MARK: - Storage worker

/// Single source of truth. SwiftData store synced to the user's private
/// iCloud database when entitlements allow it; plain local store otherwise.
final class StorageWorker {
    static let shared = StorageWorker()

    static let stateDidChange = Notification.Name("StorageWorker.stateDidChange")

    /// Syncs through the user's private iCloud database (paid dev account,
    /// entitlements wired in project.yml). Falls back to a local store when
    /// iCloud is unavailable.
    private static let iCloudSyncEnabled = true

    private let container: ModelContainer
    private let context: ModelContext

    private init() {
        // With the app-group entitlement SwiftData silently moved its default
        // store into the group container; carry the pre-group store over so
        // 1.0.x users keep their data after updating.
        Self.migrateStoreToAppGroupIfNeeded()
        let schema = Schema([JarCategory.self, JarTransaction.self, JarSettings.self,
                             JarAccount.self, JarRevision.self])
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
        publishWidgetSnapshot()

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
            .map { BudgetCategory(id: $0.id, name: $0.name, order: $0.order, goalAmount: $0.goalAmount, goalDate: $0.goalDate) }
    }

    func category(id: UUID) -> BudgetCategory? {
        categoryModel(id: id).map { BudgetCategory(id: $0.id, name: $0.name, order: $0.order, goalAmount: $0.goalAmount, goalDate: $0.goalDate) }
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
            billsAmount: model.billsAmount,
            foodPlanEnd: model.foodPlanEnd
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
            .reduce(Decimal.zero) {
                $0 + ($1.kind == .expense || $1.kind == .transferOut ? -$1.amount : $1.amount)
            }
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

    func setGoal(categoryId: UUID, amount: Decimal?, date: Date?) {
        guard let model = categoryModel(id: categoryId) else { return }
        model.goalAmount = amount
        model.goalDate = amount == nil ? nil : date
        save()
    }

    /// Moves money between jars as a linked pair of transactions.
    func transfer(from sourceId: UUID, to targetId: UUID, amount: Decimal) {
        guard sourceId != targetId, amount > 0 else { return }
        let date = Date()
        let sourceName = category(id: sourceId)?.name ?? ""
        let targetName = category(id: targetId)?.name ?? ""
        context.insert(JarTransaction(
            categoryId: sourceId, kind: .transferOut, amount: amount,
            note: String(localized: "Transfer to \(targetName)"), date: date))
        context.insert(JarTransaction(
            categoryId: targetId, kind: .transferIn, amount: amount,
            note: String(localized: "Transfer from \(sourceName)"), date: date))
        save()
    }

    /// Re-inserts a deleted transaction with its original id (undo).
    func restoreTransaction(_ dto: MoneyTransaction) {
        context.insert(JarTransaction(id: dto.id, categoryId: dto.categoryId, kind: dto.kind,
                                      amount: dto.amount, note: dto.note, date: dto.date))
        save()
    }

    /// Re-inserts a deleted category with its history and settings links (undo).
    func restoreCategory(_ dto: BudgetCategory, transactions: [MoneyTransaction],
                         wasFood: Bool, wasApartment: Bool, wasBills: Bool) {
        context.insert(JarCategory(id: dto.id, name: dto.name, order: dto.order,
                                   goalAmount: dto.goalAmount, goalDate: dto.goalDate))
        for transaction in transactions {
            context.insert(JarTransaction(
                id: transaction.id, categoryId: transaction.categoryId, kind: transaction.kind,
                amount: transaction.amount, note: transaction.note, date: transaction.date))
        }
        if let settings = settingsModel() {
            if wasFood { settings.foodCategoryId = dto.id }
            if wasApartment { settings.apartmentCategoryId = dto.id }
            if wasBills { settings.billsCategoryId = dto.id }
        }
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
        model.foodPlanEnd = dto.foodPlanEnd
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

    func revisions() -> [RevisionRecord] {
        let fetch = FetchDescriptor<JarRevision>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return ((try? context.fetch(fetch)) ?? []).map {
            RevisionRecord(
                id: $0.id, date: $0.date, planned: $0.planned, counted: $0.counted,
                entries: (try? JSONDecoder().decode([RevisionEntry].self, from: $0.entriesData)) ?? []
            )
        }
    }

    func addRevision(planned: Decimal, counted: Decimal, entries: [RevisionEntry]) {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        context.insert(JarRevision(date: Date(), planned: planned, counted: counted, entriesData: data))
        save()
    }

    private struct BackupPayload: Codable {
        var exportedAt: Date
        var categories: [BudgetCategory]
        var transactions: [MoneyTransaction]
        var settings: AppSettings
        var accounts: [ReconciliationAccount]
        var revisions: [BackupRevision]
    }

    private struct BackupRevision: Codable {
        var date: Date
        var planned: Decimal
        var counted: Decimal
        var entries: [RevisionEntry]
    }

    /// Full backup of everything the app knows, as pretty-printed JSON.
    func exportJSON() -> Data? {
        let allTransactions = sortedCategories()
            .flatMap { transactions(categoryId: $0.id) }
            .sorted { $0.date < $1.date }
        let payload = BackupPayload(
            exportedAt: Date(),
            categories: sortedCategories(),
            transactions: allTransactions,
            settings: settings(),
            accounts: accounts(),
            revisions: revisions().map {
                BackupRevision(date: $0.date, planned: $0.planned, counted: $0.counted, entries: $0.entries)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    /// Restores a backup produced by `exportJSON`, replacing everything.
    /// Returns false if the data doesn't decode as a Jarz backup.
    func importJSON(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else { return false }

        for model in (try? context.fetch(FetchDescriptor<JarTransaction>())) ?? [] { context.delete(model) }
        for model in (try? context.fetch(FetchDescriptor<JarCategory>())) ?? [] { context.delete(model) }
        for model in (try? context.fetch(FetchDescriptor<JarAccount>())) ?? [] { context.delete(model) }
        for model in (try? context.fetch(FetchDescriptor<JarRevision>())) ?? [] { context.delete(model) }
        for model in (try? context.fetch(FetchDescriptor<JarSettings>())) ?? [] { context.delete(model) }

        for category in payload.categories {
            context.insert(JarCategory(id: category.id, name: category.name, order: category.order,
                                       goalAmount: category.goalAmount, goalDate: category.goalDate))
        }
        for transaction in payload.transactions {
            context.insert(JarTransaction(
                id: transaction.id, categoryId: transaction.categoryId, kind: transaction.kind,
                amount: transaction.amount, note: transaction.note, date: transaction.date))
        }
        for (index, account) in payload.accounts.enumerated() {
            context.insert(JarAccount(id: account.id, name: account.name,
                                      amount: account.amount, order: index))
        }
        for revision in payload.revisions {
            let entriesData = (try? JSONEncoder().encode(revision.entries)) ?? Data()
            context.insert(JarRevision(date: revision.date, planned: revision.planned,
                                       counted: revision.counted, entriesData: entriesData))
        }
        saveSettings(payload.settings)
        return true
    }

    /// True when the store is CloudKit-backed and an iCloud account is signed in.
    func iCloudSyncActive() -> Bool {
        Self.iCloudSyncEnabled && FileManager.default.ubiquityIdentityToken != nil
    }

    func deleteRevision(id: UUID) {
        let fetch = FetchDescriptor<JarRevision>(predicate: #Predicate { $0.id == id })
        guard let model = (try? context.fetch(fetch))?.first else { return }
        context.delete(model)
        save()
    }

    // MARK: Internals

    private static func migrateStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        guard let groupDir = fm.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetShared.groupId)?
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        else { return }
        let oldDir = URL.applicationSupportDirectory
        let oldStore = oldDir.appendingPathComponent("default.store")
        let newStore = groupDir.appendingPathComponent("default.store")
        // Only when the group store doesn't exist yet — never overwrite data
        // the user may have created after updating.
        guard fm.fileExists(atPath: oldStore.path),
              !fm.fileExists(atPath: newStore.path) else { return }
        try? fm.createDirectory(at: groupDir, withIntermediateDirectories: true)
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            let source = oldDir.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { continue }
            try? fm.copyItem(at: source, to: groupDir.appendingPathComponent(name))
        }
        // Rename instead of deleting — the old files stay as a safety net.
        try? fm.moveItem(at: oldStore, to: oldDir.appendingPathComponent("default.store.pre-group"))
    }

    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
        publishWidgetSnapshot()
        Reminders.reschedule(worker: self)
    }

    /// Mirrors the food state into the app group so the widget can render
    /// without touching the SwiftData store.
    func publishWidgetSnapshot() {
        let settings = settings()
        guard let foodId = settings.foodCategoryId, settings.dailyFoodAmount > 0 else {
            WidgetShared.save(nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        WidgetShared.save(FoodSnapshot(
            name: category(id: foodId)?.name ?? NSLocalizedString("Food", comment: ""),
            balance: balance(of: foodId),
            daily: settings.dailyFoodAmount,
            planEnd: settings.foodPlanEnd,
            currencySymbol: settings.currencySymbol
        ))
        WidgetCenter.shared.reloadAllTimelines()
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

        // Seed names are localized once at creation; afterwards they're user data.
        let keys = ["Food", "Apartment", "Bills", "Gifts", "Trips", "Sport",
                    "Savings", "Clothes", "Skincare", "Phone"]
        var created: [String: JarCategory] = [:]
        for (index, key) in keys.enumerated() {
            let category = JarCategory(
                name: NSLocalizedString(key, comment: "seed jar name"), order: index)
            created[key] = category
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
