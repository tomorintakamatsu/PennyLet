import Foundation

struct Budget: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var monthlyIncome: Double
    var monthlyEssentials: Double?
    var monthlySavingsGoal: Double?
    var description: String?
    var payDay: Int?
    var currency: String?
    var language: String?
    var theme: String?
    var colorMode: String?
    var font: String?
    var categoryLimits: [String: Double]?
    var startOfWeek: String?
    var autoAnalysisEnabled: Bool?
    var dailyAnalysisTime: String?
    var weeklyAnalysisTime: String?
    var monthlyAnalysisTime: String?
    var budgetAlertsEnabled: Bool?
    var budgetAlertsEmailEnabled: Bool?
    var budgetAlertsPushEnabled: Bool?
    var alertEmail: String?
    var customCategories: [String]?
    var createdDate: String?
    var updatedDate: String?

    enum CodingKeys: String, CodingKey {
        case id, description, currency, language, theme, font
        case monthlyIncome = "monthly_income"
        case monthlyEssentials = "monthly_essentials"
        case monthlySavingsGoal = "monthly_savings_goal"
        case payDay = "pay_day"
        case colorMode = "color_mode"
        case categoryLimits = "category_limits"
        case startOfWeek = "start_of_week"
        case autoAnalysisEnabled = "auto_analysis_enabled"
        case dailyAnalysisTime = "daily_analysis_time"
        case weeklyAnalysisTime = "weekly_analysis_time"
        case monthlyAnalysisTime = "monthly_analysis_time"
        case budgetAlertsEnabled = "budget_alerts_enabled"
        case budgetAlertsEmailEnabled = "budget_alerts_email_enabled"
        case budgetAlertsPushEnabled = "budget_alerts_push_enabled"
        case alertEmail = "alert_email"
        case customCategories = "custom_categories"
        case createdDate = "created_date"
        case updatedDate = "updated_date"
    }
}

struct BudgetData: Codable {
    var monthlyIncome: Double
    var monthlyEssentials: Double?
    var monthlySavingsGoal: Double?
    var description: String?
    var payDay: Int?
    var currency: String?
    var language: String?
    var theme: String?
    var colorMode: String?
    var font: String?
    var startOfWeek: String?
    var autoAnalysisEnabled: Bool?
    var dailyAnalysisTime: String?
    var weeklyAnalysisTime: String?
    var monthlyAnalysisTime: String?
    var budgetAlertsEnabled: Bool?
    var budgetAlertsEmailEnabled: Bool?
    var budgetAlertsPushEnabled: Bool?
    var alertEmail: String?
    var customCategories: [String]?

    enum CodingKeys: String, CodingKey {
        case description, currency, language, theme, font
        case monthlyIncome = "monthly_income"
        case monthlyEssentials = "monthly_essentials"
        case monthlySavingsGoal = "monthly_savings_goal"
        case payDay = "pay_day"
        case colorMode = "color_mode"
        case startOfWeek = "start_of_week"
        case autoAnalysisEnabled = "auto_analysis_enabled"
        case dailyAnalysisTime = "daily_analysis_time"
        case weeklyAnalysisTime = "weekly_analysis_time"
        case monthlyAnalysisTime = "monthly_analysis_time"
        case budgetAlertsEnabled = "budget_alerts_enabled"
        case budgetAlertsEmailEnabled = "budget_alerts_email_enabled"
        case budgetAlertsPushEnabled = "budget_alerts_push_enabled"
        case alertEmail = "alert_email"
        case customCategories = "custom_categories"
    }
}
