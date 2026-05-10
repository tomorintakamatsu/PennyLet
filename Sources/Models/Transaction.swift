import Foundation

struct Transaction: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var amount: Double
    var type: TransactionType
    var category: String?
    var note: String?
    var date: String
    var merchant: String?
    var description: String?
    var isRecurring: Bool
    var tags: [String]?
    var createdDate: String?
    var updatedDate: String?
    var originalCurrency: String?
    var originalAmount: Double?
    var exchangeRate: Double?
    var baseCurrency: String?

    enum TransactionType: String, Codable, Sendable {
        case expense, income
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, type, category, note, date, merchant, description, tags
        case isRecurring = "is_recurring"
        case createdDate = "created_date"
        case updatedDate = "updated_date"
        case originalCurrency = "original_currency"
        case originalAmount = "original_amount"
        case exchangeRate = "exchange_rate"
        case baseCurrency = "base_currency"
    }

    var dateValue: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: date) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: date) { return d }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: date)
    }

    var signedAmount: Double {
        type == .expense ? -amount : amount
    }
}

struct TransactionData: Codable {
    var amount: Double
    var type: Transaction.TransactionType
    var category: String?
    var note: String?
    var date: String
    var merchant: String?
    var description: String?
    var isRecurring: Bool
    var tags: [String]?
    var originalCurrency: String?
    var originalAmount: Double?
    var exchangeRate: Double?
    var baseCurrency: String?

    init(
        amount: Double,
        type: Transaction.TransactionType,
        category: String? = nil,
        note: String? = nil,
        date: String,
        merchant: String? = nil,
        description: String? = nil,
        isRecurring: Bool = false,
        tags: [String]? = nil,
        originalCurrency: String? = nil,
        originalAmount: Double? = nil,
        exchangeRate: Double? = nil,
        baseCurrency: String? = nil
    ) {
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.date = date
        self.merchant = merchant
        self.description = description
        self.isRecurring = isRecurring
        self.tags = tags
        self.originalCurrency = originalCurrency
        self.originalAmount = originalAmount
        self.exchangeRate = exchangeRate
        self.baseCurrency = baseCurrency
    }

    enum CodingKeys: String, CodingKey {
        case amount, type, category, note, date, merchant, description, tags
        case isRecurring = "is_recurring"
        case originalCurrency = "original_currency"
        case originalAmount = "original_amount"
        case exchangeRate = "exchange_rate"
        case baseCurrency = "base_currency"
    }
}
