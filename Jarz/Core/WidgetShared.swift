import Foundation

/// Snapshot the app writes into the app-group container for the widget.
/// The widget recomputes the per-day plan with FoodMath at render time,
/// so entries stay correct across midnights without waking the app.
struct FoodSnapshot: Codable {
    var name: String
    var balance: Decimal
    var daily: Decimal
    var planEnd: Date?
    var currencySymbol: String
}

enum WidgetShared {
    static let groupId = "group.com.antonpenkov.jarz"
    static let fileName = "widget.json"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupId)?
            .appendingPathComponent(fileName)
    }

    static func load() -> FoodSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(FoodSnapshot.self, from: data)
    }

    static func save(_ snapshot: FoodSnapshot?) {
        guard let url = fileURL else { return }
        guard let snapshot else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
