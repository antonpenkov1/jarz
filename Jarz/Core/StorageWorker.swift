import Foundation

/// Single source of truth for app data, persisted as JSON in Application Support.
/// Scenes read through their interactors and mutate via `update(_:)`.
final class StorageWorker {
    static let shared = StorageWorker()

    static let stateDidChange = Notification.Name("StorageWorker.stateDidChange")

    private(set) var state: AppState
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Jarz", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("state.json")
        }
        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            state = decoded
        } else {
            state = Self.seededState()
            persist()
        }
    }

    func update(_ mutate: (inout AppState) -> Void) {
        mutate(&state)
        persist()
        NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
    }

    func balance(of categoryId: UUID) -> Decimal {
        state.transactions
            .filter { $0.categoryId == categoryId }
            .reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    func totalBalance() -> Decimal {
        state.categories.reduce(Decimal.zero) { $0 + balance(of: $1.id) }
    }

    func sortedCategories() -> [BudgetCategory] {
        state.categories.sorted { $0.order < $1.order }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func seededState() -> AppState {
        let names = ["Food", "Apartment", "Bills", "Gifts", "Trips", "Sport",
                     "Savings", "Clothes", "Skincare", "Phone"]
        let categories = names.enumerated().map { BudgetCategory(name: $1, order: $0) }
        var settings = AppSettings()
        settings.foodCategoryId = categories.first { $0.name == "Food" }?.id
        settings.apartmentCategoryId = categories.first { $0.name == "Apartment" }?.id
        settings.billsCategoryId = categories.first { $0.name == "Bills" }?.id
        return AppState(categories: categories, settings: settings)
    }
}
