import Foundation

enum MoneyFormat {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static func amount(_ value: Decimal) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    static func money(_ value: Decimal, symbol: String) -> String {
        let text = amount(value)
        return symbol.isEmpty ? text : "\(text) \(symbol)"
    }

    /// Parses user input, tolerating both "." and "," as decimal separators
    /// and spaces as grouping.
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
