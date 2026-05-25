import Foundation

struct Goal: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: String?
    var category: String?
    var paymentAmount: Double?
    var frequency: String?
    var startDate: String?
    var createdDate: String?
    var updatedDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, frequency
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case targetDate = "target_date"
        case paymentAmount = "payment_amount"
        case startDate = "start_date"
        case createdDate = "created_date"
        case updatedDate = "updated_date"
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }

    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }
}

struct GoalData: Codable {
    var name: String
    var targetAmount: Double
    var currentAmount: Double?
    var targetDate: String?
    var category: String?
    var paymentAmount: Double?
    var frequency: String?
    var startDate: String?

    enum CodingKeys: String, CodingKey {
        case name, category, frequency
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case targetDate = "target_date"
        case paymentAmount = "payment_amount"
        case startDate = "start_date"
    }
}
