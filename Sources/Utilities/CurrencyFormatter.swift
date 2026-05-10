import Foundation

enum CurrencyFormat {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    nonisolated(unsafe) static var language = "en" {
        didSet { updateLocale() }
    }

    private static func updateLocale() {
        switch language {
        case "ja": formatter.locale = Locale(identifier: "ja_JP")
        case "zh": formatter.locale = Locale(identifier: "zh_Hans")
        default:   formatter.locale = Locale(identifier: "en_US")
        }
    }

    static func format(_ amount: Double, currency: String = "USD") -> String {
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    static func formatSigned(_ amount: Double, currency: String = "USD") -> String {
        let prefix = amount >= 0 ? "+" : "−"
        return prefix + format(abs(amount), currency: currency)
    }

    static func currencySymbol(for currency: String = "USD") -> String {
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? "$"
    }

    static func formatForeign(_ amount: Double, currency: String) -> String {
        formatter.currencyCode = currency
        let noDecimal = ["JPY", "KRW"].contains(currency)
        formatter.maximumFractionDigits = noDecimal ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    static func formatForeignSigned(_ amount: Double, currency: String) -> String {
        let prefix = amount >= 0 ? "+" : "−"
        return prefix + formatForeign(abs(amount), currency: currency)
    }
}
