import SwiftUI

struct AppCategory: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let icon: String
    let color: Color

    static let expenseCategories: [AppCategory] = [
        .init(id: "food", label: "Food & Dining", icon: "fork.knife", color: .orange),
        .init(id: "groceries", label: "Groceries", icon: "basket.fill", color: .green),
        .init(id: "transport", label: "Transport", icon: "car.fill", color: .blue),
        .init(id: "shopping", label: "Shopping", icon: "bag.fill", color: .pink),
        .init(id: "entertainment", label: "Entertainment", icon: "tv.fill", color: .purple),
        .init(id: "health", label: "Health", icon: "heart.fill", color: .red),
        .init(id: "bills", label: "Bills & Utilities", icon: "doc.text.fill", color: .yellow),
        .init(id: "rent", label: "Rent / Housing", icon: "house.fill", color: .indigo),
        .init(id: "subscriptions", label: "Subscriptions", icon: "repeat", color: .cyan),
        .init(id: "travel", label: "Travel", icon: "airplane", color: .teal),
        .init(id: "education", label: "Education", icon: "graduationcap.fill", color: .mint),
        .init(id: "gifts", label: "Gifts", icon: "gift.fill", color: .red),
        .init(id: "other", label: "Other", icon: "ellipsis.circle.fill", color: .gray),
    ]

    static let incomeCategories: [AppCategory] = [
        .init(id: "salary", label: "Salary", icon: "briefcase.fill", color: .green),
        .init(id: "freelance", label: "Freelance", icon: "laptopcomputer", color: .blue),
        .init(id: "investment", label: "Investment", icon: "chart.line.uptrend.xyaxis", color: .purple),
        .init(id: "gift_in", label: "Gift", icon: "gift.fill", color: .pink),
        .init(id: "other_in", label: "Other", icon: "ellipsis.circle.fill", color: .gray),
    ]

    static func category(for id: String?, type: Transaction.TransactionType) -> AppCategory {
        let list = type == .income ? incomeCategories : expenseCategories
        return list.first { $0.id == id } ?? list.last!
    }
}
