import Foundation

actor CurrencyRateService {
    static let shared = CurrencyRateService()

    private let baseURL = "https://api.frankfurter.app"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private var memoryCache: [String: Double] = [:]
    private var lastFetchDate: Date?
    private let cacheTTL: TimeInterval = 3600

    static let supportedCurrencies: [(code: String, name: String, symbol: String)] = [
        ("USD", "US Dollar", "$"),
        ("EUR", "Euro", "€"),
        ("GBP", "British Pound", "£"),
        ("JPY", "Japanese Yen", "¥"),
        ("CAD", "Canadian Dollar", "C$"),
        ("AUD", "Australian Dollar", "A$"),
        ("CHF", "Swiss Franc", "CHF"),
        ("CNY", "Chinese Yuan", "¥"),
        ("HKD", "Hong Kong Dollar", "HK$"),
        ("SGD", "Singapore Dollar", "S$"),
        ("KRW", "South Korean Won", "₩"),
        ("BRL", "Brazilian Real", "R$"),
    ]

    private struct RateResponse: Codable {
        let amount: Double
        let base: String
        let date: String
        let rates: [String: Double]
    }

    func isExpired() -> Bool {
        guard let last = lastFetchDate else { return true }
        return Date().timeIntervalSince(last) > cacheTTL
    }

    func clearCache() {
        memoryCache = [:]
        lastFetchDate = nil
    }

    func getAllRates(base: String) async throws -> [String: Double] {
        if !isExpired(), !memoryCache.isEmpty {
            return memoryCache
        }

        let urlString = "\(baseURL)/latest?from=\(base)"
        guard let url = URL(string: urlString) else {
            throw CurrencyRateError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CurrencyRateError.networkError
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CurrencyRateError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let rateResponse = try decoder.decode(RateResponse.self, from: data)

        memoryCache = rateResponse.rates
        lastFetchDate = Date()
        return memoryCache
    }

    func refreshRates(base: String) async throws -> [String: Double] {
        clearCache()
        return try await getAllRates(base: base)
    }

    func getRate(from: String, to: String) async throws -> Double {
        if from == to { return 1.0 }

        // frankfurter.app uses EUR as base when no base is specified, but we always fetch
        // with our desired base. If from != the base we last fetched, we need to cross-convert.
        let rates = try await getAllRates(base: "USD")

        guard let usdToFrom = from == "USD" ? 1.0 : rates[from],
              let usdToTarget = to == "USD" ? 1.0 : rates[to] else {
            throw CurrencyRateError.unsupportedCurrency
        }

        // Cross rate: if 1 USD = X FROM and 1 USD = Y TO, then 1 FROM = Y/X TO
        return usdToTarget / usdToFrom
    }

    func convert(amount: Double, from: String, to: String) async throws -> (converted: Double, rate: Double) {
        let rate = try await getRate(from: from, to: to)
        let converted = (amount * rate * 100).rounded() / 100
        return (converted, rate)
    }
}

enum CurrencyRateError: Error {
    case invalidURL
    case networkError
    case serverError(Int)
    case unsupportedCurrency

    var localizationKey: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network error"
        case .serverError: return "Server error"
        case .unsupportedCurrency: return "Currency not supported"
        }
    }
}
