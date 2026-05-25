import Foundation

enum SpendCalculator {
    static func monthTransactions(_ transactions: [Transaction], date: Date = Date()) -> [Transaction] {
        transactions.filter { tx in
            guard let txDate = Date.fromDateString(tx.date) ?? Date.fromISOString(tx.date) else {
                return false
            }
            return txDate.isSameMonth(as: date)
        }
    }

    static func getSpendSummary(transactions: [Transaction], budget: Budget?, today: Date = Date()) -> SpendSummary {
        let monthTx = monthTransactions(transactions, date: today)
        let spent = monthTx
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        let incomeThisMonth = monthTx
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }

        let monthlyIncome = budget?.monthlyIncome ?? 0
        let essentials = budget?.monthlyEssentials ?? 0
        let savings = budget?.monthlySavingsGoal ?? 0

        let monthlyDisposable = max(monthlyIncome - essentials - savings, 0)
        let remaining = monthlyDisposable - spent

        let monthEnd = today.endOfMonth
        let daysLeft = max(Date.daysBetween(today, monthEnd) + 1, 1)
        let safeDaily = max(remaining / Double(daysLeft), 0)

        let totalDays = today.daysInMonth
        let dayOfMonth = today.dayOfMonth
        let expectedSpent = (monthlyDisposable * Double(dayOfMonth)) / Double(totalDays)
        let paceDiff = spent - expectedSpent

        return SpendSummary(
            spent: spent,
            incomeThisMonth: incomeThisMonth,
            monthlyDisposable: monthlyDisposable,
            remaining: remaining,
            daysLeft: daysLeft,
            safeDaily: safeDaily,
            paceDiff: paceDiff,
            expectedSpent: expectedSpent,
            dayOfMonth: dayOfMonth,
            totalDays: totalDays,
            spendPercent: monthlyDisposable > 0 ? min((spent / monthlyDisposable) * 100, 100) : 0
        )
    }

    static func getCategoryBreakdown(transactions: [Transaction], today: Date = Date()) -> [CategoryBreakdown] {
        let monthTx = monthTransactions(transactions, date: today)
            .filter { $0.type == .expense }

        var map: [String: Double] = [:]
        for tx in monthTx {
            let key = tx.category ?? "other"
            map[key, default: 0] += tx.amount
        }

        return map.map { CategoryBreakdown(id: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
