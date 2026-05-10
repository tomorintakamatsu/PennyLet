import Foundation

struct User: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var email: String?
    var name: String?
    var isPro: Bool?
    var monthlyUsage: MonthlyUsage?
    var createdDate: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case isPro = "is_pro"
        case monthlyUsage = "monthly_usage"
        case createdDate = "created_date"
    }
}

struct MonthlyUsage: Codable, Equatable, Sendable {
    var month: String
    var daily: Int
    var insight: Int
    var recap: Int
    var receipt: Int
    var forecast: Int

    static var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    static var empty: MonthlyUsage {
        MonthlyUsage(month: currentMonthKey, daily: 0, insight: 0, recap: 0, receipt: 0, forecast: 0)
    }

    var isCurrentMonth: Bool {
        month == MonthlyUsage.currentMonthKey
    }
}
