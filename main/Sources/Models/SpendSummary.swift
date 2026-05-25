import Foundation

struct SpendSummary: Sendable {
    let spent: Double
    let incomeThisMonth: Double
    let monthlyDisposable: Double
    let remaining: Double
    let daysLeft: Int
    let safeDaily: Double
    let paceDiff: Double
    let expectedSpent: Double
    let dayOfMonth: Int
    let totalDays: Int
    let spendPercent: Double

    var balance: Double { incomeThisMonth - spent }
    var isOverBudget: Bool { remaining < 0 }
}

struct CategoryBreakdown: Identifiable, Sendable {
    let id: String
    let amount: Double

    var category: AppCategory {
        AppCategory.category(for: id, type: .expense)
    }
}
