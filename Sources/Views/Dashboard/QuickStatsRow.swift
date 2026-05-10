import SwiftUI

struct QuickStatsRow: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: viewModel.loc("Spent"),
                amount: summary.spent,
                icon: "arrow.up.forward",
                color: .red,
                currency: currency
            )
            StatCard(
                title: viewModel.loc("Income"),
                amount: summary.incomeThisMonth,
                icon: "arrow.down.forward",
                color: .green,
                currency: currency
            )
            StatCard(
                title: viewModel.loc("Balance"),
                amount: summary.balance,
                icon: "equal",
                color: summary.balance >= 0 ? .blue : .red,
                currency: currency
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let currency: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(CurrencyFormat.format(abs(amount), currency: currency))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
